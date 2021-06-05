import 'dart:async';
import 'dart:html';

import 'package:dnd_interactive/actions.dart';

import '../communication.dart';
import '../edit_image.dart';
import '../font_awesome.dart';
import '../game.dart';
import 'dialog.dart';
import 'upload.dart' as uploader;

final HtmlElement _panel = querySelector('#editGamePanel');
final InputElement _gameNameInput = _panel.querySelector('#gameName');
final HtmlElement _roster = _panel.querySelector('#editChars');
final ButtonElement _cancelButton = _panel.querySelector('button.close');
final ButtonElement _deleteButton = _panel.querySelector('button#delete');
final ButtonElement _saveButton = _panel.querySelector('button#save');

final _chars = <_EditChar>[];

String _gameId;
int _idCounter = 0;
final ButtonElement _addCharButton = _panel.querySelector('#addChar')
  ..onClick.listen((event) {
    _chars.add(_EditChar(_idCounter++, '', '')..focus());
    _updateAddButton();
  });

Future<void> display(Game game, [HtmlElement title, HtmlElement refEl]) async {
  _gameId = game.id;
  var result = await socket.request(GAME_EDIT, {'id': game.id});
  if (result is String) return print('Error: $result');

  _saveButton.disabled = false;

  _gameNameInput
    ..value = game.name
    ..focus();
  _chars.forEach((c) => c.e.remove());
  _chars.clear();
  var charJsons = List<Map>.from(result['pcs']);
  for (var i = 0; i < charJsons.length; i++) {
    _chars.add(_EditChar(
        i, charJsons[i]['name'], getGameFile('pc$i', gameId: _gameId)));
  }
  _idCounter = charJsons.length;

  _updateAddButton();

  var closer = Completer();
  var subs = [
    _saveButton.onClick.listen((event) async {
      _saveButton.disabled = true;
      if (await _saveChanges(game.id)) {
        title?.text = _gameNameInput.value;
        closer.complete();
      }
    }),
    _cancelButton.onClick.listen((event) => closer.complete()),
    _deleteButton.onClick.listen((event) async {
      if (await _delete(game)) {
        refEl.remove();
        closer.complete();
      }
    })
  ];

  _panel.classes.add('show');

  await closer.future;
  _panel.classes.remove('show');
  subs.forEach((s) => s.cancel());
}

void _updateAddButton() {
  _addCharButton.disabled = _chars.length >= 20;
}

class _EditChar {
  final HtmlElement e;
  final int id;
  InputElement _nameInput;
  String get name => _nameInput.value;

  _EditChar(this.id, String name, String imgUrl) : e = LIElement() {
    e
      ..append(registerEditImage(
        DivElement()
          ..className = 'edit-img'
          ..append(DivElement()..text = 'Change')
          ..append(ImageElement(src: imgUrl)),
        upload: _changeIcon,
      ))
      ..append(_nameInput = InputElement()
        ..placeholder = 'Name...'
        ..value = name)
      ..append(iconButton('times', className: 'bad')
        ..onClick.listen((event) {
          remove();
        }));

    _roster.append(e);
  }

  Future<String> _changeIcon([Blob initialFile]) async {
    return await uploader.display(
      action: GAME_CHARACTER_UPLOAD,
      type: IMAGE_TYPE_PC,
      initialImg: initialFile,
      extras: {
        'id': id,
        'gameId': _gameId,
      },
    );
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

Future<bool> _saveChanges(String id) async {
  return await socket.request(GAME_EDIT, {
    'id': id,
    'data': {
      'name': _gameNameInput.value,
      'pcs': _chars.map((e) => e.toJson()).toList(),
    },
  });
}

Future<bool> _delete(Game game) async {
  var confirmed = await Dialog<bool>(
    'Delete Campaign?',
    onClose: () => false,
    okText: 'Delete forever',
    okClass: 'bad',
  ).addParagraph('''
    All of <b>${game.name}</b>'s characters, maps and scenes,
    along with their uploaded images, will be immediately removed from the
    server. This action can't be undone.''').display();
  return confirmed && await socket.request(GAME_DELETE, {'id': game.id});
}
