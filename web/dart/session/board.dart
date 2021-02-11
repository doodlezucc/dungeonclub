import 'dart:html';
import 'dart:math';

import 'grid.dart';
import 'movable.dart';
import 'session.dart';

class Board {
  final Session session;
  final HtmlElement e = querySelector('#board');
  final HtmlElement container = querySelector('#boardContainer');
  final ImageElement ground = querySelector('#board #ground');
  final grid = Grid();
  final movables = <Movable>[];

  Point _position;
  Point get position => _position;
  set position(Point pos) {
    _position = pos;
    _transform();
  }

  double _zoom = 0;
  double _scaledZoom = 1;
  double get zoom => _zoom;
  double get scaledZoom => _scaledZoom;
  set zoom(double zoom) {
    _zoom = zoom;
    _scaledZoom = exp(zoom);
    _transform();
  }

  void _transform() {
    e.style.transform =
        'scale($_scaledZoom) translate(${position.x}px, ${position.y}px)';
  }

  Board(this.session) {
    position = Point(0, 0);

    grid.resize(ground.width, ground.height);

    var drag = false;
    container.onMouseDown.listen((event) async {
      if ((event.target as HtmlElement).className.contains('movable')) return;
      drag = true;
      await window.onMouseUp.first;
      drag = false;
    });
    window.onMouseMove.listen((event) {
      if (drag) {
        position += event.movement * (1 / _scaledZoom);
      }
    });

    container.onMouseWheel.listen((event) {
      zoom -= event.deltaY / 300;
    });
  }

  Movable addMovable(String img) {
    var m = Movable(board: this, img: img);
    movables.add(m);
    grid.e.append(m.e);
    return m;
  }
}
