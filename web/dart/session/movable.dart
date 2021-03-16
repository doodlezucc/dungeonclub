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

  int _size;
  int get size => _size;
  set size(int size) {
    _size = size;
    e.style.setProperty('--size', '$size');
  }

  Movable({this.board, String img, this.id, Point pos})
      : e = DivElement()..className = 'movable' {
    onImageChange(img);
    position = pos ?? Point(0, 0);
    size = 1;

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
      if (drag && !board.grid.editingGrid) {
        offset += event.movement * (1 / board.scaledZoom);

        snapToGrid(start + offset);
      }
    });
  }

  void onMove(Point pos) {
    position = pos;
  }

  void onImageChange(String img) {
    e.style.backgroundImage = 'url($img)';
  }

  void snapToGrid([Point pos]) {
    pos = pos ?? position;
    var cell = board.grid.cellSize;
    position = Point(
      (pos.x / cell).floor() * cell,
      (pos.y / cell).floor() * cell,
    );
  }
}
