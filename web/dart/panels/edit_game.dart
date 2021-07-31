import 'dart:async';
import 'dart:html';

import 'package:dnd_interactive/actions.dart';

import '../../main.dart';
import '../communication.dart';
import '../edit_image.dart';
import '../font_awesome.dart';
import '../game.dart';
import 'dialog.dart';
import 'panel_overlay.dart';
import 'upload.dart' as uploader;

final HtmlElement _panel = querySelector('#editGamePanel');
final InputElement _gameNameInput = _panel.querySelector('#gameName');
final HtmlElement _roster = _panel.querySelector('#editChars');
final ButtonElement _cancelButton = _panel.querySelector('button.close');
final ButtonElement _deleteButton = _panel.querySelector('button#delete');
final ButtonElement _saveButton = _panel.querySelector('button#save');
final DivElement _startingScene = registerEditImage(
  _panel.querySelector('#startingScene'),
  upload: ([Blob initialFile]) async => await uploader.displayOffline(
    type: IMAGE_TYPE_SCENE,
    initialImg: initialFile,
    processUpload: (base64, maxRes, upscale) async {
      _sceneImgData = base64;
      _saveButton.disabled = false;
      return 'data:image/jpeg;base64,$base64';
    },
  ),
);

final _chars = <_EditChar>[];

String _sceneImgData;
String _gameId;
int _idCounter = 0;
final AnchorElement _addCharButton = _panel.querySelector('#addChar')
  ..onClick.listen((_) {
    _chars.add(_EditChar(_idCounter++)..focus());
    _updateAddButton();
  });

bool _prepareMode;
bool get prepareMode => _prepareMode;
set prepareMode(bool v) {
  _prepareMode = v;
  _panel.classes.toggle('prepare', v);
}

Future<void> display(Game game, [HtmlElement title, HtmlElement refEl]) async {
  prepareMode = false;
  _gameId = game.id;
  var result = await socket.request(GAME_EDIT, {'id': game.id});
  if (result is String) return print('Error: $result');

  overlayVisible = true;
  _saveButton.disabled = false;

  _gameNameInput
    ..value = game.name
    ..focus();
  _chars.forEach((c) => c.e.remove());
  _chars.clear();
  var charJsons = List<Map>.from(result['pcs']);
  for (var i = 0; i < charJsons.length; i++) {
    _chars.add(_EditChar(i,
        name: charJsons[i]['name'],
        imgUrl: getGameFile('pc$i', gameId: _gameId)));
  }
  _idCounter = charJsons.length;

  _updateAddButton();

  var closer = Completer();
  var subs = [
    _saveButton.onClick.listen((event) async {
      _saveButton.disabled = true;
      if (await _saveChanges(game.id)) {
        title?.text = _gameNameInput.value;
        game.name = _gameNameInput.value;
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

  _panel.classes.remove('prepare');
  _panel.classes.add('show');

  await closer.future;
  _panel.classes.remove('show');
  subs.forEach((s) => s.cancel());
  overlayVisible = false;
}

Future<Game> displayPrepare() async {
  // Initialize edit-img
  _startingScene.className += '';

  prepareMode = true;
  overlayVisible = true;
  _saveButton.disabled = true;

  _gameNameInput
    ..value = ''
    ..focus();
  _chars.forEach((c) => c.e.remove());
  _chars.clear();
  _idCounter = 0;

  _updateAddButton();

  var closer = Completer();
  var subs = [
    _saveButton.onClick.listen((_) async {
      _saveButton.disabled = true;
      closer.complete(await _createGameAndJoin());
    }),
    _cancelButton.onClick.listen((_) => closer.complete()),
  ];

  _panel.classes.addAll(['show', 'prepare']);

  var result = await closer.future;
  _panel.classes.remove('show');
  subs.forEach((s) => s.cancel());
  overlayVisible = false;

  return result;
}

void _updateAddButton() {
  _addCharButton.classes.toggle('disabled', _chars.length >= 20);
}

class _EditChar {
  final HtmlElement e;
  final int id;
  String bufferedImg;
  InputElement _nameInput;
  String get name => _nameInput.value;

  _EditChar(this.id,
      {String name = '', String imgUrl = 'images/default_pc.jpg'})
      : e = LIElement() {
    e
      ..append(registerEditImage(
        DivElement()
          ..className = 'edit-img responsive'
          ..append(DivElement()..text = 'Change')
          ..append(ImageElement(src: imgUrl)),
        upload: _changeIcon,
      ))
      ..append(_nameInput = InputElement()
        ..placeholder = 'Name...'
        ..value = name)
      ..append(iconButton('times', className: 'bad')
        ..onClick.listen((_) => remove()));

    _roster.append(e);
  }

  Future<String> _changeIcon([Blob initialFile]) async {
    _panel.classes.add('upload');

    String result;
    if (_prepareMode) {
      result = await uploader.displayOffline(
        type: IMAGE_TYPE_PC,
        initialImg: initialFile,
        processUpload: (base64, maxRes, upscale) async {
          bufferedImg = base64;
          return 'data:image/jpeg;base64,$base64';
        },
      );
    } else {
      result = await uploader.display(
        action: GAME_CHARACTER_UPLOAD,
        type: IMAGE_TYPE_PC,
        initialImg: initialFile,
        extras: {
          'id': id,
          'gameId': _gameId,
        },
      );
    }

    _panel.classes.remove('upload');
    return result;
  }

  void remove() {
    _chars.remove(this);
    e.remove();
    _updateAddButton();
  }

  void focus() {
    _nameInput.focus();
  }

  Map<String, dynamic> toJson() => {'name': name};
}

Map<String, dynamic> _currentDataJson() => {
      'name': _gameNameInput.value,
      'pcs': _chars.map((e) => e.toJson()).toList(),
    };

Future<Game> _createGameAndJoin() async {
  var name = _gameNameInput.value;

  var session = await socket.request(GAME_CREATE_NEW, {
    'pics': _chars.map((pc) => pc.bufferedImg).toList(),
    'scene': _sceneImgData,
    'data': _currentDataJson()
  });
  if (session == null) return null;

  var game = Game(session['id'], name, true);
  user.joinFromJson(session, true);
  return game;
}

Future<bool> _saveChanges(String id) async {
  return await socket
      .request(GAME_EDIT, {'id': id, 'data': _currentDataJson()});
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
