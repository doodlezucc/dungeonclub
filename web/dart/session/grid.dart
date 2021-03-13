import 'dart:html';

class Grid {
  final HtmlElement e;
  CanvasElement _canvas;

  double _cellSize = 100;
  double get cellSize => _cellSize;
  set cellSize(double cellSize) {
    _cellSize = cellSize;
    redrawCanvas();
  }

  Point _offset = Point(0, 0);
  Point get offset => _offset;
  set offset(Point offset) {
    _offset = Point(
        (offset.x + _cellSize) % _cellSize, (offset.y + _cellSize) % _cellSize);
    redrawCanvas();
  }

  Grid() : e = querySelector('#grid') {
    _canvas = e.children.first;
  }

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
}
