import 'dart:html';

class Grid {
  final HtmlElement e;
  CanvasElement _canvas;

  double _cellSize;
  double get cellSize => _cellSize;
  set cellSize(double cellSize) {
    _cellSize = cellSize;
    redrawCanvas();
  }

  Point _offset;
  Point get offset => _offset;
  set offset(Point offset) {
    _offset = offset;
    e.style.left = '${offset.x}px';
    e.style.top = '${offset.y}px';
  }

  Grid() : e = querySelector('#grid') {
    _canvas = e.children.first;
    offset = Point(0, 0);
    cellSize = 100;
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
    for (var x = 0.0; x < _canvas.width; x += _cellSize) {
      ctx.moveTo(x, 0);
      ctx.lineTo(x, _canvas.height);
    }
    for (var y = 0.0; y < _canvas.height; y += _cellSize) {
      ctx.moveTo(0, y);
      ctx.lineTo(_canvas.width, y);
    }
    ctx.stroke();
  }
}
