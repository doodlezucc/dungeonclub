import 'dart:html';

import 'package:dnd_interactive/actions.dart';

import '../../main.dart';
import '../communication.dart';
import '../panels/upload.dart' as upload;

final HtmlElement _scenesContainer = querySelector('#scenes');
final ButtonElement _addScene = _scenesContainer.querySelector('#addScene')
  ..onClick.listen((event) async {
    var json = await upload.display(
      action: GAME_SCENE_ADD,
      type: IMAGE_TYPE_SCENE,
    );

    if (json != null) {
      return Scene(_maxScene + 1).enterEdit(json);
    }
  });

int _maxScene = 0;

class Scene {
  final HtmlElement e;
  final int id;
  ImageElement _img;

  bool get playing => e.classes.contains('playing');
  set playing(bool playing) => e.classes.toggle('playing', playing);

  bool get editing => e.classes.contains('editing');
  set editing(bool playing) => e.classes.toggle('editing', playing);

  String get image => _img.src;
  set image(String src) => _img.src = src;

  Scene(this.id) : e = DivElement() {
    e
      ..append(_img = ImageElement(src: getSceneImage(id)))
      ..onClick.listen((event) => enterEdit());
    _scenesContainer.insertBefore(e, _addScene);
    _maxScene = id;
  }

  Future<void> enterEdit([Map<String, dynamic> json]) async {
    if (editing) return;

    json = json ?? await socket.request(GAME_SCENE_GET, {'id': id});
    user.session.board
      ..refScene = this
      ..fromJson(id, json);
    _scenesContainer.querySelectorAll('.editing').classes.remove('editing');
    editing = true;
  }

  static String getSceneImage(int id) {
    return getGameFile('scene$id.png', cacheBreak: false);
  }
}
