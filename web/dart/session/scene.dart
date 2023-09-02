import 'dart:html';

import 'package:dungeonclub/actions.dart';

import '../../main.dart';
import '../communication.dart';
import '../html_helpers.dart';
import '../panels/upload.dart' as upload;
import '../resource.dart';

final HtmlElement _scenesContainer = queryDom('#scenes');
final ButtonElement _addScene = _scenesContainer.queryDom('#addScene')
  ..onLMB.listen((ev) async {
    var json = await upload.display(
      event: ev,
      action: GAME_SCENE_ADD,
      type: IMAGE_TYPE_SCENE,
      simulateHoverClass: queryDom('#sceneSelector'),
    );

    if (json != null) {
      final session = user.session!;
      if (session.scenes.length == 1) {
        session.scenes.first.enableRemove = true;
      }

      final resource = Resource(json['image']);
      final scene = Scene(json['id'], resource);
      session.scenes.add(scene);
      Scene.updateAddSceneButton();
      await scene.enterEdit(json);
    }
  });

class Scene {
  final HtmlElement e;
  final Resource background;
  final int id;
  late HtmlElement _bg;
  late ButtonElement _remove;

  bool get isPlaying => user.session!.playingScene == this;
  bool get isEditing => user.session!.board.refScene == this;

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
          ..onClick.listen((_) => sendRemove())));
    applyBackground();
    _scenesContainer.insertBefore(e, _addScene);
  }

  Scene.fromJson(Map<String, dynamic> json)
      : this(json['id'], Resource(json['image']));

  void applyBackground() {
    final src = background.url;
    _bg.style.backgroundImage = 'url("$src")';
  }

  void applyEditPlayState() {
    _bg.classes.toggle('playing', isPlaying);
    _bg.classes.toggle('editing', isEditing);
  }

  void sendRemove() {
    socket.sendAction(GAME_SCENE_REMOVE, {'id': id});

    user.session!.scenes.remove(this);
    e.remove();

    updateAddSceneButton();
  }

  void enterPlay() {
    if (isPlaying) return;

    user.session!.playingScene = this;
    user.session!.applySceneEditPlayStates();
    socket.sendAction(GAME_SCENE_PLAY, {'id': id});
  }

  Future<void> enterEdit([Map<String, dynamic>? json]) async {
    if (isEditing) return;

    json = json ?? await socket.request(GAME_SCENE_GET, {'id': id});
    user.session!.board.fromJson(json!, setAsPlaying: false);
  }

  static void updateAddSceneButton() {
    final scenes = user.session!.scenes;
    final reachedLimit = scenes.length >= user.getScenesPerCampaign();

    _addScene.disabled = reachedLimit;
    _addScene.title = reachedLimit
        ? "You can't have more than ${user.getScenesPerCampaign()} scenes at a time."
        : '';

    scenes.first.enableRemove = scenes.length != 1;
  }
}
