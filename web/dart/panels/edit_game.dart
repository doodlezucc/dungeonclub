import 'dart:async';
import 'dart:html';

import '../communication.dart';
import '../font_awesome.dart';
import '../game.dart';
import '../server_actions.dart';

final HtmlElement _panel = querySelector('#editGamePanel');
final InputElement _gameNameInput = _panel.querySelector('#gameName');
final HtmlElement _roster = _panel.querySelector('#editChars');

List<_EditChar> _chars;

final ButtonElement _addCharButton = _panel.querySelector('#addChar')
  ..onClick.listen((event) {
    _chars.add(_EditChar({
      'name': '',
      'img': '',
    }));
  });

final ButtonElement _saveButton = _panel.querySelector('.save');

Future<void> display(Game game) async {
  var result = await socket.request(GAME_EDIT, {'id': game.id});
  if (result is String) return print('Error: $result');

  _saveButton.disabled = false;

  _gameNameInput.value = game.name;
  _chars?.forEach((c) => c.e.remove());
  _chars = List.from(result['pcs']).map((e) => _EditChar(e)).toList();

  StreamSubscription sub;
  sub = _saveButton.onClick.listen((event) async {
    _saveButton.disabled = true;
    await sub.cancel();
    await _saveChanges(game.id);
  });

  _panel.classes.add('show');
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

    _roster.insertBefore(e, _addCharButton);
  }

  void remove() {
    _chars.remove(this);
    e.remove();
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'img': '',
      };
}

Future<void> _saveChanges(String id) async {
  await socket.sendAction(GAME_EDIT, {
    'id': id,
    'data': {
      'name': _gameNameInput.value,
      'pcs': _chars.map((e) => e.toJson()).toList(),
    },
  });
  _panel.classes.remove('show');
}
