import 'dart:html';
import 'dart:math';

import 'package:dnd_interactive/point_json.dart';

import '../../main.dart';
import 'prefab.dart';

final HtmlElement _controls = querySelector('#sceneEditor');
final InputElement _gridCellSize = _controls.querySelector('#gridSize');
final InputElement _gridColor = _controls.querySelector('#gridColor');
final InputElement _gridAlpha = _controls.querySelector('#gridAlpha');

class Grid {
  final HtmlElement e;
  final CanvasElement _canvas = querySelector('#board canvas');

  num _cellSize = 100;
  num get cellSize => _cellSize;
  set cellSize(num cellSize) {
    _cellSize = max(8, cellSize);
    _clampOffset();
    e.style.setProperty('--cell-size', '$_cellSize');
    user.session.board.movables.forEach((m) => m.snapToGrid());
    redrawCanvas();
  }

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
    _offset = Point(
        (offset.x + _cellSize) % _cellSize, (offset.y + _cellSize) % _cellSize);
  }

  Grid() : e = querySelector('#grid') {
    _initGridEditor();
  }

  void _initGridEditor() {
    _gridCellSize.onInput.listen((event) {
      cellSize = _gridCellSize.valueAsNumber;
    });

    _gridColor.onInput.listen((_) => redrawCanvas());
    _gridAlpha.onInput.listen((_) => redrawCanvas());
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
  }

  void redrawCanvas() {
    var ctx = _canvas.context2D;
    ctx.clearRect(0, 0, _canvas.width, _canvas.height);
    ctx.globalAlpha = _gridAlpha.valueAsNumber;
    ctx.strokeStyle = _gridColor.value;
    ctx.beginPath();
    for (var x = offset.x; x <= _canvas.width; x += _cellSize) {
      var xr = x.round() - 0.5;
      ctx.moveTo(xr, 0);
      ctx.lineTo(xr, _canvas.height);
    }
    for (var y = 0.5 + offset.y; y <= _canvas.height; y += _cellSize) {
      var yr = y.round() - 0.5;
      ctx.moveTo(0, yr);
      ctx.lineTo(_canvas.width, yr);
    }
    ctx.closePath();
    ctx.stroke();
  }

  Map<String, dynamic> toJson() => {
        'offset': writePoint(offset),
        'cellSize': cellSize,
        'color': _gridColor.value,
        'alpha': _gridAlpha.valueAsNumber,
      };

  void fromJson(Map<String, dynamic> json) {
    cellSize = json['cellSize'];
    _gridCellSize.valueAsNumber = cellSize;
    _gridColor.value = json['color'];
    _gridAlpha.valueAsNumber = json['alpha'];
    offset = parsePoint(json['offset']);
  }
}
