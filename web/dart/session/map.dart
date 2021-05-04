import 'dart:html';

final HtmlElement _e = querySelector('#map');
final ImageElement _img = _e.querySelector('selectors');

class GameMap {
  String get image => _img.src;
  set image(String image) {
    _img.src = image;
  }

  bool get visible => _e.classes.contains('show');
  set visible(bool visible) {
    _e.classes.toggle('show', visible);
  }
}
