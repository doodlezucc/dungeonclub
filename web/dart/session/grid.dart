import 'dart:html';
import 'dart:math';

import 'package:dnd_interactive/actions.dart';
import 'package:dnd_interactive/point_json.dart';

import '../../main.dart';
import '../communication.dart';

final HtmlElement _controls = querySelector('#sceneEditor');
final ButtonElement _editGrid = _controls.querySelector('#editGrid');
final HtmlElement _gridControls = _controls.querySelector('#gridControls');
final InputElement _gridCellSize = _controls.querySelector('#gridSize');
final InputElement _gridColor = _controls.querySelector('#gridColor');

class Grid {
  final HtmlElement e;
  final CanvasElement _canvas = querySelector('#board canvas');
  bool get editingGrid => _editGrid.classes.contains('active');

  num _cellSize = 100;
  num get cellSize => _cellSize;
  set cellSize(num cellSize) {
    _cellSize = max(8, cellSize);
    _clampOffset();
    e.style.width = '${_cellSize}px';
    e.style.height = '${_cellSize}px';
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

    _gridColor.onInput.listen((event) {
      redrawCanvas();
    });

    _editGrid.onClick.listen((event) {
      var enable = _editGrid.classes.toggle('active');
      _gridControls.classes.toggle('disabled', !enable);

      if (!enable) {
        socket.sendAction(GAME_SCENE_UPDATE, {
          'grid': toJson(),
        });
      }
    });
  }

  void resize(int width, int height) {
    _canvas.width = width;
    _canvas.height = height;
    redrawCanvas();
  }

  void redrawCanvas() {
    var ctx = _canvas.context2D;
    ctx.clearRect(0, 0, _canvas.width, _canvas.height);
    ctx.strokeStyle = _gridColor.value;
    ctx.beginPath();
    for (var x = offset.x; x <= _canvas.width; x += _cellSize) {
      var xr = x.round() + 0.5;
      ctx.moveTo(xr, 0);
      ctx.lineTo(xr, _canvas.height);
    }
    for (var y = 0.5 + offset.y; y <= _canvas.height; y += _cellSize) {
      var yr = y.round() + 0.5;
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
      };

  void fromJson(Map<String, dynamic> json) {
    cellSize = json['cellSize'];
    _gridCellSize.valueAsNumber = cellSize;
    _gridColor.value = json['color'];
    offset = parsePoint(json['offset']);
  }
}
