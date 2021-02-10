import 'dart:html';
import 'dart:math';

class Board {
  final HtmlElement e = querySelector('#board');
  final HtmlElement container = querySelector('#boardContainer');
  final ImageElement ground = querySelector('#board #ground');

  Point<num> _position;
  Point<num> get position => _position;
  set position(Point<num> pos) {
    _position = pos;
    e.style.left = '${pos.x}px';
    e.style.top = '${pos.y}px';
  }

  double _zoom;
  double get zoom => _zoom;
  set zoom(double z) {
    _zoom = z;
  }

  Board() {
    position = Point(0, 0);
    zoom = 1;

    var drag = false;
    container.onMouseDown.listen((event) async {
      drag = true;
      await window.onMouseUp.first;
      drag = false;
    });
    window.onMouseMove.listen((event) {
      if (drag) {
        position += event.movement;
      }
    });
  }
}
