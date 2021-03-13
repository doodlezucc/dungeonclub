import 'dart:html';

import '../communication.dart';

final HtmlElement _scenesContainer = querySelector('#scenes');
final ButtonElement _addScene = _scenesContainer.querySelector('#addScene')
  ..onClick.listen((event) {
    print('New scene pls');
  });

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
    e.append(_img = ImageElement(src: getSceneImage(id, false)));
    _scenesContainer.insertBefore(e, _addScene);
  }

  static String getSceneImage(int id, bool cacheBreak) {
    return getGameFile('scene$id.png', cacheBreak: cacheBreak);
  }
}
