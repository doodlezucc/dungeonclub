import 'dart:html';

import 'package:dnd_interactive/point_json.dart';

class Grid {
  final HtmlElement e;
  final CanvasElement _canvas = querySelector('#board canvas');

  num _cellSize = 100;
  num get cellSize => _cellSize;
  set cellSize(num cellSize) {
    _cellSize = cellSize;
    _clampOffset();
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

  Grid() : e = querySelector('#grid');

  void resize(int width, int height) {
    _canvas.width = width;
    _canvas.height = height;
    redrawCanvas();
  }

  void redrawCanvas() {
    var ctx = _canvas.context2D;
    ctx.clearRect(0, 0, _canvas.width, _canvas.height);
    ctx.setStrokeColorRgb(0, 0, 0);
    ctx.beginPath();
    for (var x = 0.5 + offset.x; x <= _canvas.width; x += _cellSize) {
      ctx.moveTo(x, 0);
      ctx.lineTo(x, _canvas.height);
    }
    for (var y = 0.5 + offset.y; y <= _canvas.height; y += _cellSize) {
      ctx.moveTo(0, y);
      ctx.lineTo(_canvas.width, y);
    }
    ctx.closePath();
    ctx.stroke();
  }

  Map<String, dynamic> toJson() => {
        'offset': writePoint(offset),
        'cellSize': cellSize,
      };

  void fromJson(Map<String, dynamic> json) {
    cellSize = json['cellSize'];
    offset = parsePoint(json['offset']);
  }
}
