import 'dart:html';
import 'dart:math';
import 'dart:svg' as svg;

import 'package:dnd_interactive/point_json.dart';

import '../../main.dart';

final HtmlElement _controls = querySelector('#sceneEditor');
final InputElement _gridTiles = _controls.querySelector('#gridTiles');
final InputElement _gridTileUnit = _controls.querySelector('#gridTileUnit');
final InputElement _gridColor = _controls.querySelector('#gridColor');
final InputElement _gridAlpha = _controls.querySelector('#gridAlpha');

class Grid {
  final HtmlElement e;
  final svg.SvgSvgElement _canvas = querySelector('#gridCanvas');
  final svg.PatternElement _pattern = querySelector('#gridPattern');
  final svg.RectElement _rect = querySelector('#gridCanvas rect');

  bool get blink => _canvas.classes.contains('blink');
  set blink(bool blink) => _canvas.classes.toggle('blink', blink);

  int _tiles = 16;
  int get tiles => _tiles;
  set tiles(int tiles) {
    _tiles = max(8, tiles);
    _clampOffset();
    _updateCellSize();
    user.session.board.movables.forEach((m) => m.roundToGrid());
    redrawCanvas();
  }

  num get cellSize => (_canvas.clientWidth - 2) / _tiles;

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

  num _tileMultiply;
  String _tileUnit;

  Grid() : e = querySelector('#grid') {
    _initGridEditor();
  }

  String tileUnitString([double distance = 1]) =>
      '${distance * _tileMultiply}$_tileUnit';

  void _validateTileUnit() {
    var s = _gridTileUnit.value.replaceFirst(',', '.');

    // Regex for real numbers (e.g. 0.125 | 10 | 420.69)
    var regex = RegExp(r'\d+(\.\d*)?');
    var match = regex.matchAsPrefix(s);

    if (match != null) {
      _tileMultiply = num.parse(match.group(0));

      if (s.length == match.end) {
        // No unit given
        _tileUnit = ' ft';
      } else {
        var suffix = s.substring(match.end);
        if (!suffix.startsWith(' ')) {
          suffix = ' $suffix';
        }
        _tileUnit = suffix;
      }
    } else {
      _tileMultiply = 5;
      _tileUnit = ' ft';
    }

    _gridTileUnit.value = tileUnitString();
  }

  void _initGridEditor() {
    _gridTiles
      ..onInput.listen((event) {
        tiles = _gridTiles.valueAsNumber;
      })
      ..onMouseEnter.listen((_) {
        blink = true;
        redrawCanvas();
      })
      ..onMouseLeave.listen((_) {
        blink = false;
        redrawCanvas();
      });

    _gridTileUnit.onChange.listen((_) {
      _validateTileUnit();
    });

    _gridColor.onInput.listen((_) => redrawCanvas());
    _gridAlpha.onInput.listen((_) => redrawCanvas());
  }

  void _updateCellSize() {
    e.style.setProperty('--cell-size', '$cellSize');
  }

  Point evToGridSpaceUnscaled(
    MouseEvent event, {
    bool round = true,
  }) {
    var size = Point<num>(0.5, 0.5);

    var p = ((event.offset - offset) * (1 / cellSize)) - size;

    if (round) {
      p = Point(p.x.round(), p.y.round());
    }
    return p;
  }

  Point evToGridSpace(
    MouseEvent event,
    num targetSize, {
    bool round = true,
  }) {
    var size = Point(targetSize * cellSize / 2, targetSize * cellSize / 2);

    var p = event.offset - offset - size;

    if (round) {
      var cs = cellSize;
      p = Point((p.x / cs).round(), (p.y / cs).round());
    }
    return p;
  }

  Point roundToCell(Point p) {
    var cs = cellSize;

    var off = Point(cs / 2, cs / 2);
    p = p - off;
    return Point((p.x / cs).round() * cs, (p.y / cs).round() * cs) + off;
  }

  void resize(int width, int height) {
    _rect.setAttribute('width', '$width');
    _rect.setAttribute('height', '$height');
    redrawCanvas();
    _updateCellSize();
  }

  void redrawCanvas() {
    var size = cellSize;
    _pattern.setAttribute('width', '$size');
    _pattern.setAttribute('height', '$size');

    svg.PathElement path = _pattern.children.first;
    path.setAttribute('stroke', _gridColor.value);
    path.setAttribute('opacity', _gridAlpha.value);
  }

  Map<String, dynamic> toJson() => {
        'offset': writePoint(offset),
        'tiles': tiles,
        'tileUnit': _gridTileUnit.value,
        'color': _gridColor.value,
        'alpha': _gridAlpha.valueAsNumber,
      };

  void fromJson(Map<String, dynamic> json) {
    tiles = json['tiles'];
    _gridTiles.valueAsNumber = tiles;
    _gridTileUnit.value = json['tileUnit'];
    _validateTileUnit();
    _gridColor.value = json['color'];
    _gridAlpha.valueAsNumber = json['alpha'];
    offset = Point(0, 0) ?? parsePoint(json['offset']);
  }
}
