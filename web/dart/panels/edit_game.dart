import 'dart:async';
import 'dart:html';

import 'package:dnd_interactive/actions.dart';

import '../communication.dart';
import '../font_awesome.dart';
import '../game.dart';
import 'upload.dart' as uploader;

final HtmlElement _panel = querySelector('#editGamePanel');
final InputElement _gameNameInput = _panel.querySelector('#gameName');
final HtmlElement _roster = _panel.querySelector('#editChars');

final _chars = <_EditChar>[];

String _gameId;
int _idCounter = 0;
final ButtonElement _addCharButton = _panel.querySelector('#addChar')
  ..onClick.listen((event) {
    _chars.add(_EditChar(_idCounter++, '', '')..focus());
    _updateAddButton();
  });

final ButtonElement _saveButton = _panel.querySelector('.save');

Future<void> display(Game game) async {
  _gameId = game.id;
  var result = await socket.request(GAME_EDIT, {'id': game.id});
  if (result is String) return print('Error: $result');

  _saveButton.disabled = false;

  _gameNameInput.value = game.name;
  _chars.forEach((c) => c.e.remove());
  _chars.clear();
  var charJsons = List<Map>.from(result['pcs']);
  for (var i = 0; i < charJsons.length; i++) {
    // ew, hardcoded url
    _chars.add(_EditChar(i, charJsons[i]['name'],
        'http://localhost:7070/database/games/$_gameId/pc$i.png'));
  }
  _idCounter = charJsons.length;

  _updateAddButton();

  StreamSubscription sub;
  sub = _saveButton.onClick.listen((event) async {
    _saveButton.disabled = true;
    await sub.cancel();
    await _saveChanges(game.id);
  });

  _panel.classes.add('show');
}

void _updateAddButton() {
  _addCharButton.disabled = _chars.length >= 20;
}

class _EditChar {
  final HtmlElement e;
  final int id;
  ImageElement _iconImg;
  InputElement _nameInput;
  String get name => _nameInput.value;

  _EditChar(this.id, String name, String imgUrl) : e = LIElement() {
    e
      ..append(DivElement()
        ..className = 'edit-img'
        ..append(DivElement()..text = 'Change')
        ..append(_iconImg = ImageElement(src: imgUrl))
        ..onClick.listen((_) => _changeIcon())
        ..onDrop.listen((e) {
          e.preventDefault();
          if (e.dataTransfer.files != null && e.dataTransfer.files.isNotEmpty) {
            _changeIcon(e.dataTransfer.files[0]);
          }
        }))
      ..append(_nameInput = InputElement()
        ..placeholder = 'Name...'
        ..value = name)
      ..append(iconButton('times', 'bad')
        ..onClick.listen((event) {
          remove();
        }));

    _roster.append(e);
  }

  Future<void> _changeIcon([Blob initialFile]) async {
    var url = await uploader.display(
      type: IMAGE_TYPE_PC,
      initialImg: initialFile,
      square: true,
      extras: {
        'id': id,
        'gameId': _gameId,
      },
    );
    if (url != null) {
      // Cachebreaker suffix for forced reloading
      _iconImg.src = '$url?${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  void remove() {
    _chars.remove(this);
    e.remove();
    _updateAddButton();
  }

  void focus() {
    _nameInput.focus();
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        //'img': basename(_iconImg.src),
      };
}

Future<void> _saveChanges(String id) async {
  var saved = await socket.request(GAME_EDIT, {
    'id': id,
    'data': {
      'name': _gameNameInput.value,
      'pcs': _chars.map((e) => e.toJson()).toList(),
    },
  });
  if (saved) {
    _panel.classes.remove('show');
  } else {
    print('Settings saved!');
  }
}
