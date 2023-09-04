import 'dart:async';
import 'dart:html';

import 'package:dungeonclub/actions.dart';

import '../../main.dart';
import '../communication.dart';
import '../edit_image.dart';
import '../html_helpers.dart';
import '../game.dart';
import '../resource.dart';
import 'dialog.dart';
import 'panel_overlay.dart';
import 'upload.dart' as uploader;

final HtmlElement _panel = queryDom('#editGamePanel');
final InputElement _gameNameInput = _panel.queryDom('#gameName');
final HtmlElement _roster = _panel.queryDom('#editChars');
final ButtonElement _cancelButton = _panel.queryDom('button.close');
final ButtonElement _deleteButton = _panel.queryDom('button#delete');
final ButtonElement _saveButton = _panel.queryDom('button#save');

final _chars = <_EditChar>[];

final AnchorElement _addCharButton = _panel.queryDom('#addChar')
  ..onClick.listen((_) {
    _chars.add(_EditChar.empty()..focus());
    _updateAddButton();
  });

bool _prepareMode = false;
bool get prepareMode => _prepareMode;
set prepareMode(bool v) {
  _prepareMode = v;
  _panel.classes.toggle('prepare', v);
}

Future<void> display(
  Game game, [
  HtmlElement? title,
  HtmlElement? refEl,
]) async {
  prepareMode = false;
  var result = await socket.request(GAME_EDIT, {'id': game.id});

  overlayVisible = true;
  _saveButton.text = 'Save Changes';
  _saveButton.disabled = false;

  _gameNameInput
    ..value = game.name
    ..focus();
  _chars.forEach((c) => c.e.remove());
  _chars.clear();

  for (var jChar in result['pcs']) {
    _chars.add(_EditChar.fromJson(game, jChar));
  }

  _updateAddButton();
  uploader.usedStorage = result['usedStorage'];

  var closer = Completer();
  var subs = [
    _saveButton.onClick.listen((event) async {
      _saveButton.disabled = true;
      if (await _saveChanges(game.id)) {
        title?.text = _gameNameInput.value;
        game.name = _gameNameInput.value!;
        closer.complete();
      }
    }),
    _cancelButton.onClick.listen((event) => closer.complete()),
    _deleteButton.onClick.listen((event) async {
      if (await _delete(game)) {
        refEl?.remove();
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

Future<Game?> displayPrepare() async {
  prepareMode = true;
  overlayVisible = true;
  _saveButton.text = 'Create Campaign';
  _saveButton.disabled = false;

  _gameNameInput.value = '';
  _gameNameInput.focus();
  _chars.forEach((c) => c.e.remove());
  _chars.clear();

  // Add 4 default characters
  for (var i = 0; i < 4; i++) {
    _chars.add(_EditChar.empty());
  }

  _updateAddButton();
  uploader.usedStorage = 0;

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
  _addCharButton.classes.toggle('disabled',
      _chars.where((char) => !char.isRemoved).length >= user.playersPerCampaign);
}

class _EditChar {
  final HtmlElement e;
  final int? id;
  final BaseResource avatar;
  bool isRemoved = false;
  String? bufferedImg;
  late InputElement _nameInput;
  String get name => _nameInput.value!;

  bool get isOG => id != null;

  _EditChar(this.id, String name, this.avatar) : e = LIElement() {
    e
      ..append(registerEditImage(
        DivElement()
          ..className = 'edit-img responsive'
          ..append(DivElement()..text = 'Change')
          ..append(ImageElement(src: avatar.url)),
        upload: _changeIcon,
      ))
      ..append(_nameInput = InputElement()
        ..placeholder = 'Name...'
        ..value = name)
      ..append(iconButton('times', className: 'bad')
        ..tabIndex = -1
        ..onClick.listen((_) => remove()));

    _roster.append(e);
  }

  _EditChar.fromJson(Game game, json)
      : this(
          json['id'],
          json['name'],
          Resource(json['prefab']['image'], game: game),
        );

  _EditChar.empty() : this(null, '', BaseResource('asset:default_pc.jpg'));

  Future<String> _changeIcon(MouseEvent ev, [Blob? initialFile]) async {
    return await uploader.display(
      event: ev,
      type: IMAGE_TYPE_PC,
      initialImg: initialFile,
      processUpload: (data, maxRes, upscale) async {
        bufferedImg = data;
        if (data.startsWith('asset')) return BaseResource(data).url;
        return 'data:image/jpeg;base64,$data';
      },
      onPanelVisible: (v) => _panel.classes.toggle('upload', v),
    );
  }

  Future<void> remove() async {
    if (isOG) {
      var confirm = await Dialog<bool>(
        'Remove Character?',
        onClose: () => false,
        okText: 'Remove $name',
      ).addParagraph(
          '''This will remove <b>$name</b> from the campaign.''').display();

      if (!confirm) return;
      isRemoved = true;
    } else {
      _chars.remove(this);
    }

    e.remove();
    _updateAddButton();
  }

  void focus() {
    _nameInput.focus();
  }

  Map<String, dynamic>? toJson() => isRemoved
      ? null
      : {
          'name': name,
          if (bufferedImg != null) 'avatar': bufferedImg,
        };
}

Map<String, dynamic> _currentDataJson() => {
      'name': _gameNameInput.value,
      'pcs': Map.of({
        for (var char in _chars)
          if (char.isOG) '${char.id}': char.toJson()
      }),
      'newPCs': [
        for (var char in _chars)
          if (!char.isOG) char.toJson()
      ],
    };

Future<Game> _createGameAndJoin() async {
  var name = _gameNameInput.value!;

  var session = await socket.request(GAME_CREATE_NEW, {
    'data': _currentDataJson(),
  });

  if (session == null) {
    throw 'Unable to create game';
  }

  var game = Game(session['id'], name, true);
  user.joinFromJson(session, false);
  return game;
}

Future<bool> _saveChanges(String id) async {
  final data = _currentDataJson();
  return await socket.request(GAME_EDIT, {'id': id, 'data': data});
}

Future<bool> _delete(Game game) async {
  var confirmed = await Dialog<bool>(
    'Delete Campaign?',
    onClose: () => false,
    okText: 'Delete Forever',
    okClass: 'bad',
  ).addParagraph('''
    All of <b>${game.name}</b>'s characters, maps and scenes,
    along with their uploaded images, will be immediately removed from the
    server. This action can't be undone.''').display();
  return confirmed && await socket.request(GAME_DELETE, {'id': game.id});
}
