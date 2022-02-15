import 'dart:html';
import 'dart:math';
import 'dart:svg' as svg;

import 'package:dnd_interactive/point_json.dart';
import 'package:web_whiteboard/util.dart';

import '../../main.dart';

final HtmlElement _controls = querySelector('#sceneEditor');
final InputElement gridTiles = _controls.querySelector('#gridTiles');
final InputElement _gridTileUnit = _controls.querySelector('#gridTileUnit');
final InputElement _gridColor = _controls.querySelector('#gridColor');
final InputElement _gridAlpha = _controls.querySelector('#gridAlpha');
final DivElement _crop = querySelector('#gridPadding');
const minSize = Point<double>(200, 200);

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
    _updateCellSize();
    user.session.board.movables.forEach((m) => m.roundToGrid());
    redrawCanvas();
  }

  Point _size = minSize;
  Point get size => _size;
  set size(Point size) {
    _size = size;
    user.session.board.movables.forEach((m) => m.roundToGrid());
    _rect.setAttribute('width', '${size.x}');
    _rect.setAttribute('height', '${size.y}');
    e.style.width = '${size.x}px';
    e.style.height = '${size.y}px';
    redrawCanvas();
    _updateCellSize();
  }

  num get cellSize => (_size.x - 1) / _tiles;
  Point<double> get _imgSize =>
      Point(_canvas.clientWidth.toDouble(), _canvas.clientHeight.toDouble());

  Point _offset = Point<double>(0, 0);
  Point get offset => _offset;
  set offset(Point offset) {
    _offset = offset;
    e.style.left = '${_offset.x}px';
    e.style.top = '${_offset.y}px';
    _rect.setAttribute('transform', 'translate(${offset.x}, ${offset.y})');
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
    gridTiles
      ..onInput.listen((event) {
        tiles = gridTiles.valueAsNumber;
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

    _crop.onMouseDown.listen((e) async {
      if (e.button != 0) return;
      e.preventDefault();
      HtmlElement clicked = e.target;
      var pos1 = offset;
      var size1 = size;

      void Function(Point<double>) action;
      if (clicked != _crop) {
        var cursorCss = clicked.style.cursor + ' !important';
        document.body.style.cursor = cursorCss;
        _crop.style.cursor = cursorCss;

        var classes = clicked.classes;
        var t = classes.contains('top');
        var r = classes.contains('right');
        var l = classes.contains('left');
        var b = classes.contains('bottom');

        action = (diff) {
          var x = pos1.x;
          var y = pos1.y;
          var width = size1.x;
          var height = size1.y;

          var maxPosDiff = size1 - minSize;
          var minPosDiff = pos1 * -1;

          if (t) {
            var v = min(max(diff.y, minPosDiff.y), maxPosDiff.y);
            y += v;
            height -= v;
          }
          if (r) width += diff.x;
          if (b) height += diff.y;
          if (l) {
            var v = min(max(diff.x, minPosDiff.x), maxPosDiff.x);
            x += v;
            width -= v;
          }

          _setPosAndSize(Point(x, y), Point(width, height));
        };
      } else {
        action = (diff) {
          _setPosAndSize(pos1 + diff, forceDoublePoint(size));
        };
      }

      var mouse1 = Point<double>(e.client.x, e.client.y);
      var subMove = window.onMouseMove.listen((e) {
        if (e.movement.magnitude == 0) return;
        var diff = Point<double>(e.client.x, e.client.y) - mouse1;

        action(diff * (1 / user.session.board.scaledZoom));
      });

      await window.onMouseUp.first;

      document.body.style.cursor = '';
      _crop.style.cursor = '';
      await subMove.cancel();
    });
  }

  void _setPosAndSize(Point p, Point<double> s) {
    p = forceDoublePoint(p);
    offset = clamp(p, Point(0, 0), _imgSize - forceDoublePoint(size));
    size = clamp(s, minSize, _imgSize - forceDoublePoint(offset));
    offset = clamp(p, Point(0, 0), _imgSize - forceDoublePoint(size));

    _crop.style.left = '${_offset.x}px';
    _crop.style.top = '${_offset.y}px';
    _crop.style.width = '${_size.x}px';
    _crop.style.height = '${_size.y}px';
  }

  void _updateCellSize() {
    e.style.setProperty('--cell-size', '$cellSize');
  }

  Point offsetToGridSpaceUnscaled(
    Point point, {
    bool round = true,
    Point offset = const Point(0.5, 0.5),
  }) {
    var p = ((point - offset - _offset) * (1 / cellSize)) - offset;

    if (round) {
      p = Point(p.x.round(), p.y.round());
    }
    return p;
  }

  Point offsetToGridSpace(
    Point point,
    num targetSize, {
    bool round = true,
  }) {
    var size = Point(targetSize * cellSize / 2, targetSize * cellSize / 2);

    var p = point - offset - size;

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
    if (offset.x + size.x > width || offset.y + size.y > height) {
      _setPosAndSize(Point(0, 0), Point(width.toDouble(), height.toDouble()));
    }
  }

  void redrawCanvas() {
    var size = cellSize;
    _pattern.setAttribute('width', '$size');
    _pattern.setAttribute('height', '$size');

    svg.PathElement path = _pattern.children.first;
    path.setAttribute('stroke', _gridColor.value);
    path.setAttribute('opacity', _gridAlpha.value);
  }

  void configure({
    int tiles,
    String tileUnit,
    String color,
    double alpha,
    Point position,
    Point size,
  }) {
    this.tiles = tiles;
    gridTiles.valueAsNumber = this.tiles;
    _gridTileUnit.value = tileUnit;
    _validateTileUnit();
    _gridColor.value = color;
    _gridAlpha.valueAsNumber = alpha;
    _setPosAndSize(position, forceDoublePoint(size ?? _imgSize));
  }

  Map<String, dynamic> toJson() => {
        'offset': writePoint(offset),
        'size': writePoint(size),
        'tiles': tiles,
        'tileUnit': _gridTileUnit.value,
        'color': _gridColor.value,
        'alpha': _gridAlpha.valueAsNumber,
      };

  void fromJson(Map<String, dynamic> json) {
    configure(
      tiles: json['tiles'],
      tileUnit: json['tileUnit'],
      color: json['color'],
      alpha: json['alpha'],
      position: parsePoint(json['offset']),
      size: parsePoint(json['size']),
    );
  }
}
