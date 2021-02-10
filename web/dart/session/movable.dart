import 'dart:html';
import 'dart:math';

import 'board.dart';

class Movable {
  final HtmlElement e;
  final Board board;

  bool accessible = true;
  Point<num> _position;
  Point<num> get position => _position;
  Point<num> get snapPosition => Point<num>(_position.x, _position.y);
  set position(Point<num> position) {
    _position = position;
    var snap = snapPosition;
    e.style.left = '${snap.x}px';
    e.style.top = '${snap.y}px';
  }

  Movable({this.board, String img})
      : e = DivElement()
          ..className = 'movable'
          ..append(ImageElement(src: img)) {
    position = Point(0, 0);

    var drag = false;
    e
      ..onMouseDown.listen((event) async {
        drag = true;
        await window.onMouseUp.first;
        drag = false;
      });

    window.onMouseMove.listen((event) {
      if (drag) {
        position += event.movement * (1 / board.scaledZoom);
      }
    });
  }
}
