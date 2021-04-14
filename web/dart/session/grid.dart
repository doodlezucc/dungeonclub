import 'dart:html';
import 'dart:math';

import 'package:dnd_interactive/point_json.dart';

import '../../main.dart';
import 'prefab.dart';

final HtmlElement _controls = querySelector('#sceneEditor');
final InputElement _gridTiles = _controls.querySelector('#gridTiles');
final InputElement _gridColor = _controls.querySelector('#gridColor');
final InputElement _gridAlpha = _controls.querySelector('#gridAlpha');

class Grid {
  final HtmlElement e;
  final CanvasElement _canvas = querySelector('#board canvas');

  int _tiles = 16;
  int get tiles => _tiles;
  set tiles(int tiles) {
    _tiles = max(8, tiles);
    _clampOffset();
    _updateCellSize();
    user.session.board.movables.forEach((m) => m.snapToGrid());
    redrawCanvas();
  }

  num get cellSize => _canvas.width / _tiles;

  Point _offset = Point(0, 0);
  Point get offset => _offset;
  set offset(Point offset) {
    _offset = offset;
    _clampOffset();
    e.style.left = '${_offset.x}px';
    e.style.top = '${_offset.y}px';
    redrawCanvas();
  }

  void _clampOffset() {
    var size = cellSize;
    _offset = Point((offset.x + size) % size, (offset.y + size) % size);
  }

  Grid() : e = querySelector('#grid') {
    _initGridEditor();
  }

  void _initGridEditor() {
    _gridTiles
      ..onInput.listen((event) {
        tiles = _gridTiles.valueAsNumber;
      })
      ..onMouseEnter.listen((_) {
        _canvas.classes.add('blink');
        redrawCanvas(forceVisibility: true);
      })
      ..onMouseLeave.listen((_) {
        _canvas.classes.remove('blink');
        redrawCanvas();
      });

    _gridColor.onInput.listen((_) => redrawCanvas());
    _gridAlpha.onInput.listen((_) => redrawCanvas());
  }

  void _updateCellSize() {
    e.style.setProperty('--cell-size', '$cellSize');
  }

  Point evToGridSpace(
    MouseEvent event,
    EntityBase entity, {
    bool round = true,
  }) {
    var size = Point(entity.size * cellSize / 2, entity.size * cellSize / 2);

    var p = event.offset - offset - size;

    if (round) {
      var cs = cellSize;
      p = Point((p.x / cs).round() * cs, (p.y / cs).round() * cs);
    }
    return p;
  }

  void resize(int width, int height) {
    _canvas.width = width;
    _canvas.height = height;
    redrawCanvas();
    _updateCellSize();
  }

  void redrawCanvas({bool forceVisibility = false}) {
    var ctx = _canvas.context2D;
    ctx.clearRect(0, 0, _canvas.width, _canvas.height);
    ctx.globalAlpha = forceVisibility ? 1 : _gridAlpha.valueAsNumber;
    ctx.strokeStyle = forceVisibility ? '#ffffff' : _gridColor.value;
    ctx.beginPath();
    for (var x = offset.x; x < _canvas.width; x += cellSize) {
      var xr = x.round() - 0.5;
      ctx.moveTo(xr, 0);
      ctx.lineTo(xr, _canvas.height);
    }
    for (var y = offset.y; y < _canvas.height; y += cellSize) {
      var yr = y.round() - 0.5;
      ctx.moveTo(0, yr);
      ctx.lineTo(_canvas.width, yr);
    }
    ctx.closePath();
    ctx.stroke();
  }

  Map<String, dynamic> toJson() => {
        'offset': writePoint(offset),
        'tiles': tiles,
        'color': _gridColor.value,
        'alpha': _gridAlpha.valueAsNumber,
      };

  void fromJson(Map<String, dynamic> json) {
    tiles = json['tiles'];
    _gridTiles.valueAsNumber = tiles;
    _gridColor.value = json['color'];
    _gridAlpha.valueAsNumber = json['alpha'];
    offset = Point(0, 0) ?? parsePoint(json['offset']);
  }
}
