import 'dart:html';

import 'package:dungeonclub/actions.dart';
import 'package:dungeonclub/limits.dart';

import '../../main.dart';
import '../communication.dart';
import '../font_awesome.dart';
import '../panels/upload.dart' as upload;
import '../resource.dart';

final HtmlElement _scenesContainer = querySelector('#scenes');
final ButtonElement _addScene = _scenesContainer.querySelector('#addScene')
  ..onLMB.listen((ev) async {
    var json = await upload.display(
      event: ev,
      action: GAME_SCENE_ADD,
      type: IMAGE_TYPE_SCENE,
      simulateHoverClass: querySelector('#sceneSelector'),
    );

    if (json != null) {
      final session = user.session;
      if (session.scenes.length == 1) {
        session.scenes.first.enableRemove = true;
      }

      final scene = Scene(json['id'], json['image']);
      session.scenes.add(scene);
      await scene.enterEdit(json);
    }
  });

class Scene {
  final HtmlElement e;
  final Resource background;
  int id;
  HtmlElement _bg;
  ButtonElement _remove;

  bool get playing => _bg.classes.contains('playing');
  set playing(bool playing) => _bg.classes.toggle('playing', playing);

  bool get editing => _bg.classes.contains('editing');
  set editing(bool playing) => _bg.classes.toggle('editing', playing);

  set enableRemove(bool enable) => _remove.disabled = !enable;

  Scene(this.id, this.background)
      : e = DivElement()..className = 'scene-preview' {
    e
      ..append(_bg = DivElement()
        ..append(iconButton('wrench', label: 'Edit')
          ..onClick.listen((_) => enterEdit())))
      ..append(SpanElement()
        ..append(iconButton('play', className: 'play', label: 'Play')
          ..onClick.listen((_) => enterPlay()))
        ..append(_remove = iconButton('trash', className: 'bad')
          ..onClick.listen((_) => remove())));
    applyBackground();
    _scenesContainer.insertBefore(e, _addScene);
  }

  Scene.fromJson(Map<String, dynamic> json)
      : this(json['id'], Resource(json['image']));

  void applyBackground() {
    final src = background.url;
    print(src);
    _bg.style.backgroundImage = 'url($src)';
  }

  Future<void> remove() async {
    var result = await socket.request(GAME_SCENE_REMOVE, {'id': id});

    if (result == null) return;

    user.session.scenes.remove(this);
    updateAddSceneButton();

    // var next = _allScenes[max(0, id - 1)];
    // if (playing) {
    //   await next.enterPlay();
    // } else if (editing) {
    //   await next.enterEdit();
    // }
    e.remove();
  }

  Future<void> enterPlay([Map<String, dynamic> json]) async {
    if (playing) return;

    json = json ?? await socket.request(GAME_SCENE_PLAY, {'id': id});
    if (!editing) {
      user.session.board
        ..refScene = this
        ..fromJson(json);
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
      ..fromJson(json);
    _scenesContainer.querySelectorAll('.editing').classes.remove('editing');
    editing = true;
  }

  static void updateAddSceneButton() {
    final scenes = user.session.scenes;
    final reachedLimit = scenes.length >= scenesPerCampaign;

    _addScene.disabled = reachedLimit;
    _addScene.title = reachedLimit
        ? "You can't have more than $scenesPerCampaign scenes at a time."
        : '';

    scenes.first.enableRemove = scenes.length == 1;
  }
}
