import 'dart:async';
import 'dart:html';

import 'package:dnd_interactive/actions.dart';

import '../communication.dart';
import '../font_awesome.dart';
import '../game.dart';

final HtmlElement _panel = querySelector('#editGamePanel');
final InputElement _gameNameInput = _panel.querySelector('#gameName');
final HtmlElement _roster = _panel.querySelector('#editChars');

List<_EditChar> _chars;

final ButtonElement _addCharButton = _panel.querySelector('#addChar')
  ..onClick.listen((event) {
    _chars.add(_EditChar({
      'name': '',
      'img': '',
    })
      ..focus());
    _updateAddButton();
  });

final ButtonElement _saveButton = _panel.querySelector('.save');

Future<void> display(Game game) async {
  var result = await socket.request(GAME_EDIT, {'id': game.id});
  if (result is String) return print('Error: $result');

  _saveButton.disabled = false;

  _gameNameInput.value = game.name;
  _chars?.forEach((c) => c.e.remove());
  _chars = List.from(result['pcs']).map((e) => _EditChar(e)).toList();

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
  InputElement _nameInput;
  String get name => _nameInput.value;

  _EditChar(Map<String, dynamic> json) : e = LIElement() {
    e
      ..append(DivElement()
        ..className = 'edit-img'
        ..append(DivElement()..text = 'Change')
        ..append(ImageElement(src: json['img'])))
      ..append(_nameInput = InputElement()
        ..placeholder = 'Name...'
        ..value = json['name'])
      ..append(iconButton('times', 'bad')
        ..onClick.listen((event) {
          remove();
        }));

    _roster.append(e);
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
        'img': '',
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
