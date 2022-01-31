import 'dart:html';
import 'dart:math';

import 'package:dnd_interactive/actions.dart';
import 'package:dnd_interactive/limits.dart';

import '../../main.dart';
import '../communication.dart';
import '../font_awesome.dart';
import '../panels/upload.dart' as upload;

final HtmlElement _scenesContainer = querySelector('#scenes');
final ButtonElement _addScene = _scenesContainer.querySelector('#addScene')
  ..onClick.listen((ev) async {
    var json = await upload.display(
      event: ev,
      action: GAME_SCENE_ADD,
      type: IMAGE_TYPE_SCENE,
    );

    if (json != null) {
      if (_allScenes.length == 1) {
        _allScenes.first.enableRemove = true;
      }
      return Scene(_allScenes.length).enterEdit(json);
    }
  });

List<Scene> _allScenes = [];

void _updateAddSceneButton() {
  var reachedLimit = _allScenes.length >= scenesPerCampaign;
  _addScene.disabled = reachedLimit;
  _addScene.title = reachedLimit
      ? "You can't have more than $scenesPerCampaign scenes at a time."
      : '';
}

class Scene {
  final HtmlElement e;
  int id;
  HtmlElement _bg;
  ButtonElement _remove;

  bool get playing => _bg.classes.contains('playing');
  set playing(bool playing) => _bg.classes.toggle('playing', playing);

  bool get editing => _bg.classes.contains('editing');
  set editing(bool playing) => _bg.classes.toggle('editing', playing);

  set image(String src) => _bg.style.backgroundImage = 'url($src)';

  set enableRemove(bool enable) => _remove.disabled = !enable;

  Scene(this.id) : e = DivElement() {
    e
      ..append(_bg = DivElement()
        ..append(iconButton('wrench', label: 'Edit')
          ..onClick.listen((_) => enterEdit())))
      ..append(SpanElement()
        ..append(iconButton('play', className: 'play', label: 'Play')
          ..onClick.listen((_) => enterPlay()))
        ..append(_remove = iconButton('trash', className: 'bad')
          ..onClick.listen((_) => remove())));
    image = getSceneImage(id, cacheBreak: true);
    _scenesContainer.insertBefore(e, _addScene);
    _allScenes.add(this);
    _updateAddSceneButton();
  }

  Future<void> remove() async {
    var result = await socket.request(GAME_SCENE_REMOVE, {'id': id});

    if (result == null) return;

    for (var i = id + 1; i < _allScenes.length; i++) {
      _allScenes[i].id = i - 1;
    }
    _allScenes.remove(this);
    _updateAddSceneButton();

    var next = _allScenes[max(0, id - 1)];
    if (playing) {
      await next.enterPlay();
    } else if (editing) {
      await next.enterEdit();
    }
    e.remove();

    if (_allScenes.length == 1) {
      _allScenes.first.enableRemove = false;
    }
  }

  Future<void> enterPlay([Map<String, dynamic> json]) async {
    if (playing) return;

    json = json ?? await socket.request(GAME_SCENE_PLAY, {'id': id});
    if (!editing) {
      user.session.board
        ..refScene = this
        ..fromJson(id, json);
    }

    user.session.board.showInactiveSceneWarning = false;
    _scenesContainer.querySelectorAll('.editing').classes.remove('editing');
    editing = true;
    _scenesContainer.querySelectorAll('.playing').classes.remove('playing');
    playing = true;
  }

  Future<void> enterEdit([Map<String, dynamic> json]) async {
    if (editing) return;

    json = json ?? await socket.request(GAME_SCENE_GET, {'id': id});
    user.session.board
      ..refScene = this
      ..showInactiveSceneWarning = !playing
      ..fromJson(id, json);
    _scenesContainer.querySelectorAll('.editing').classes.remove('editing');
    editing = true;
  }

  static String getSceneImage(int id, {bool cacheBreak = false}) {
    return getGameFile('scene$id', cacheBreak: cacheBreak);
  }
}
