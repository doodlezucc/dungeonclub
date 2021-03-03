import 'dart:html';
import 'dart:math';

import 'package:dnd_interactive/actions.dart';

import '../communication.dart';
import 'board.dart';

class Movable {
  int id;
  final HtmlElement e;
  final Board board;

  bool _accessible = false;
  bool get accessible => _accessible;
  set accessible(bool accessible) {
    _accessible = accessible;
    e.classes.toggle('accessible', accessible);
  }

  Point _position;
  Point get position => _position;
  set position(Point position) {
    _position = position;
    e.style.left = '${position.x}px';
    e.style.top = '${position.y}px';
  }

  void onMove(Point pos) {
    print('i was told to move lol');
    position = pos;
  }

  Movable({this.board, String img, this.id, Point pos})
      : e = DivElement()
          ..className = 'movable'
          ..append(ImageElement(src: img)) {
    position = pos ?? Point(0, 0);

    if (board.session.isGM) {
      accessible = true;
    }

    var drag = false;
    Point startPos;
    Point start;
    Point offset;

    e.onMouseDown.listen((event) async {
      if (!accessible) return;
      startPos = position;
      start = startPos + event.offset;
      offset = Point(0, 0);
      drag = true;
      await window.onMouseUp.first;
      drag = false;
      if (startPos != position) {
        print('log this pos');
        return socket.sendAction(GAME_MOVABLE_MOVE, {
          'id': id,
          'x': position.x,
          'y': position.y,
        });
      }
    });

    window.onMouseMove.listen((event) {
      if (drag) {
        offset += event.movement * (1 / board.scaledZoom);

        var cell = board.grid.cellSize;

        var pos = start + offset;
        position = Point(
          (pos.x / cell).floor() * cell,
          (pos.y / cell).floor() * cell,
        );
      }
    });
  }
}
