import 'dart:html';
import 'dart:math';

import 'package:dnd_interactive/actions.dart';
import 'package:meta/meta.dart';

import '../communication.dart';
import 'board.dart';
import 'prefab.dart';

class Movable extends EntityBase {
  int id;
  final HtmlElement e;
  final Board board;
  final Prefab prefab;

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

  @override
  set size(int size) {
    super.size = size;
    e.style.setProperty('--size', '$displaySize');
  }

  int get displaySize => size != 0 ? size : prefab.size;

  Movable({
    @required this.board,
    @required this.prefab,
    this.id,
    Point pos,
    int size = 0,
  }) : e = DivElement()..className = 'movable' {
    prefab.movables.add(this);
    onImageChange(prefab.img);
    position = pos ?? Point(0, 0);
    this.size = size ?? 0;

    if (board.session.isGM) {
      accessible = true;
    }

    var drag = false;
    Point startPos;
    Point start;
    Point offset;

    e.onMouseDown.listen((event) async {
      if (!accessible || event.button != 0 || event.target != e) return;
      startPos = position;

      var inset = board.grid.cellSize * displaySize / 2;

      start = startPos + event.offset - Point(inset, inset);

      offset = Point(0, 0);
      drag = true;
      await window.onMouseUp.first;
      drag = false;
      if (startPos != position) {
        return socket.sendAction(GAME_MOVABLE_MOVE, {
          'movable': id,
          'x': position.x,
          'y': position.y,
        });
      }
    });

    window.onMouseMove.listen((event) {
      if (drag && !board.grid.editingGrid) {
        offset += event.movement * (1 / board.scaledZoom);

        snapToGrid(pos: start + offset, roundInsteadOfFloor: true);
      }
    });

    onPrefabUpdate();
  }

  void onPrefabUpdate() {
    e.style.setProperty('--size', '$displaySize');
  }

  void onMove(Point pos) {
    position = pos;
  }

  void onImageChange(String img) {
    e.style.backgroundImage = 'url($img)';
  }

  void snapToGrid({Point pos, bool roundInsteadOfFloor = false}) {
    pos = pos ?? position;
    var cell = board.grid.cellSize;

    num modify(num v) {
      var smol = v / cell;
      return (roundInsteadOfFloor ? smol.round() : smol.floor()) * cell;
    }

    position = Point(modify(pos.x), modify(pos.y));
  }

  void onRemove() {
    prefab.movables.remove(this);
    e.remove();
  }
}
