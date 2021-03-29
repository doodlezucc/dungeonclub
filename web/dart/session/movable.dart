import 'dart:html';
import 'dart:math' as math;

import 'package:dnd_interactive/actions.dart';
import 'package:meta/meta.dart';

import '../communication.dart';
import 'board.dart';
import 'prefab.dart';

class Movable extends EntityBase {
  final HtmlElement e;
  final Board board;
  final Prefab prefab;
  final int id;

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

  Movable._({
    @required this.board,
    @required this.prefab,
    @required this.id,
    @required Point pos,
  }) : e = DivElement()..className = 'movable' {
    prefab.movables.add(this);
    onImageChange(prefab.img);
    position = pos ?? Point(0, 0);

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

        snapToGrid(pos: start + offset);
      }
    });

    onPrefabUpdate();
  }

  static Movable create({
    @required Board board,
    @required Prefab prefab,
    @required int id,
    @required Point pos,
  }) {
    if (prefab is EmptyPrefab) {
      return EmptyMovable._(board: board, prefab: prefab, id: id, pos: pos);
    }
    return Movable._(board: board, prefab: prefab, id: id, pos: pos);
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

  void snapToGrid({Point pos}) {
    pos = pos ?? position;
    var cell = board.grid.cellSize;

    num modify(num v) {
      return (v / cell).round() * cell;
    }

    position = Point(modify(pos.x), modify(pos.y));
  }

  void onRemove() {
    prefab.movables.remove(this);
    e.remove();
  }

  @override
  Map<String, dynamic> toJson() => {
        'movable': id,
        ...super.toJson(),
      };
}

class EmptyMovable extends Movable {
  SpanElement _labelSpan;

  String _label;
  String get label => _label;
  set label(String label) {
    _label = label;
    _labelSpan.text = label;

    var lines = label.split(' ');

    var length = lines.fold(0, (len, line) => math.max<int>(len, line.length));
    _labelSpan.style.setProperty('--length', '${length + 1}');
  }

  EmptyMovable._({
    @required Board board,
    @required EmptyPrefab prefab,
    @required int id,
    @required Point pos,
  }) : super._(board: board, prefab: prefab, id: id, pos: pos) {
    e
      ..classes.add('empty')
      ..append(_labelSpan = SpanElement());
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'label': label,
      };

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    label = json['label'] ?? 'AAAH';
  }
}
