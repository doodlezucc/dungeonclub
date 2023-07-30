import 'dart:html';
import 'dart:math';
import 'dart:svg' as svg;

import 'package:dungeonclub/actions.dart';
import 'package:dungeonclub/measuring/ruleset.dart';
import 'package:dungeonclub/point_json.dart';
import 'package:grid_space/grid_space.dart';

import '../../main.dart';
import '../html_helpers.dart';
import 'measuring.dart';

final HtmlElement _controls = queryDom('#sceneEditor');
final InputElement gridTiles = _controls.queryDom('#gridTiles');
final InputElement _gridTileUnit = _controls.queryDom('#gridTileUnit');
final InputElement _gridColor = _controls.queryDom('#gridColor');
final InputElement _gridAlpha = _controls.queryDom('#gridAlpha');
final DivElement _crop = queryDom('#gridPadding');
final _typeButtons = <ButtonElement, int>{
  queryDom('#gridTSquare'): GRID_SQUARE,
  queryDom('#gridTHexH'): GRID_HEX_H,
  queryDom('#gridTHexV'): GRID_HEX_V,
  queryDom('#gridTNone'): GRID_NONE,
};

const minSize = Point<double>(200, 200);

class SceneGrid {
  final HtmlElement e = queryDom('#grid');
  final svg.SvgSvgElement _canvas = queryDom('#gridCanvas');
  final svg.RectElement _rect = queryDom('#gridCanvasMask');

  Grid _grid = Grid.square(1);
  Grid get grid => _grid;

  bool get blink => _canvas.classes.contains('blink');
  set blink(bool blink) => _canvas.classes.toggle('blink', blink);

  int _gridType = GRID_SQUARE;
  int get gridType => _gridType;

  MeasuringRuleset _measuringRuleset = MeasuringRuleset.squareDmg;
  MeasuringRuleset get measuringRuleset => _measuringRuleset;

  int _tiles = 16;
  int get tiles => _tiles;
  set tiles(int tiles) {
    _tiles = max(8, tiles);
    if (_grid is TiledGrid) {
      (_grid as TiledGrid).tilesInRow = _tiles;
    } else {
      (_grid as UnclampedGrid).scale = tokenSize;
    }

    _repositionMovables();
    _applyCellSize();
    redrawCanvas();
  }

  Point get offset => _grid.zero;
  Point get size => _grid.size;

  double get cellWidth => size.x / tiles;
  double get cellHeight =>
      grid is TiledGrid ? (grid as TiledGrid).tileHeight : cellWidth;
  Point get cellSize => Point(cellWidth, cellHeight);

  double get tokenSize => cellWidth;

  Point<double> get _imgSize =>
      Point(_canvas.clientWidth.toDouble(), _canvas.clientHeight.toDouble());

  num _tileMultiply = 5;
  String _tileUnit = ' ft';

  SceneGrid() {
    _initGridEditor();
  }

  String tileUnitString([double distance = 1]) {
    var rounded = (distance * _tileMultiply);
    rounded = (rounded * 100).round() / 100;
    return '$rounded$_tileUnit';
  }

  void _validateTileUnit() {
    var s = _gridTileUnit.value!.replaceFirst(',', '.');

    // Regex for real numbers (e.g. 0.125 | 10 | 420.69)
    var regex = RegExp(r'\d+(\.\d*)?');
    var match = regex.matchAsPrefix(s);

    if (match != null) {
      _tileMultiply = num.parse(match[0]!);

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
    _typeButtons.forEach((btn, gridType) {
      btn.onClick.listen((_) => changeGridType(gridType));
    });

    gridTiles
      ..onInput.listen((event) {
        tiles = gridTiles.valueAsNumber!.toInt();
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
      final clicked = e.target as HtmlElement;
      final pos1 = offset;
      final size1 = size;

      void Function(Point<double>) action;
      if (clicked != _crop) {
        var cursorCss = clicked.style.cursor + ' !important';
        document.body!.style.cursor = cursorCss;
        _crop.style.cursor = cursorCss;

        final classes = clicked.classes;
        final t = classes.contains('top');
        final r = classes.contains('right');
        final l = classes.contains('left');
        final b = classes.contains('bottom');

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

          setPosAndSize(Point(x, y), Point(width, height));
        };
      } else {
        action = (diff) {
          setPosAndSize(pos1 + diff, size.cast<double>());
        };
      }

      final mouse1 = Point(e.client.x, e.client.y).cast<double>();
      final subMove = window.onMouseMove.listen((e) {
        if (e.movement.magnitude == 0) return;
        var diff = Point(e.client.x, e.client.y).cast<double>() - mouse1;

        action(diff * (1 / user.session!.board.scaledZoom));
      });

      await window.onMouseUp.first;

      document.body!.style.cursor = '';
      _crop.style.cursor = '';
      await subMove.cancel();
    });
  }

  void _repositionMovables() {
    user.session!.board.movables.forEach((m) => m.applyPosition());
  }

  static Grid _createGrid(int type, int tilesInRow, Point zero, Point size) {
    switch (type) {
      case GRID_SQUARE:
        return Grid.square(tilesInRow, zero: zero, size: size);
      case GRID_HEX_H:
        return Grid.hexagonal(tilesInRow,
            horizontal: true, zero: zero, size: size);
      case GRID_HEX_V:
        return Grid.hexagonal(tilesInRow,
            horizontal: false, zero: zero, size: size);
      case GRID_NONE:
        return Grid.unclamped(scale: size.x / tilesInRow, zero: zero)
          ..size = size;
    }
    throw ArgumentError('Invalid grid type $type');
  }

  void changeGridType(int type) {
    _grid = _createGrid(type, tiles, offset, size);
    _gridType = type;
    _applyGridType();
    _applyCellSize();
    _repositionMovables();
    redrawCanvas();
  }

  void _applyGrid(int tilesOverride) {
    tiles = tilesOverride;
    gridTiles.valueAsNumber = tiles;
    _applyGridType();
    _applyZero();
    _applySize();
    _applyCellSize();
    redrawCanvas();
  }

  MeasuringRuleset _defaultRulesetOfType(int gridType) {
    switch (gridType) {
      case GRID_NONE:
        return MeasuringRuleset.unclampedDefault;
      case GRID_SQUARE:
        return MeasuringRuleset.squareDmg;
      case GRID_HEX_H:
      case GRID_HEX_V:
        return MeasuringRuleset.hexDefault;
    }
    throw ArgumentError.value(gridType);
  }

  void _applyGridType() {
    _measuringRuleset = _defaultRulesetOfType(gridType);
    _typeButtons.forEach((btn, btnType) {
      btn.classes.toggle('active', btnType == gridType);
    });
    updateCanvasSvgTile();
  }

  void _applyZero() {
    _crop.style.left = '${offset.x}px';
    _crop.style.top = '${offset.y}px';
    redrawCanvas();
  }

  void _applySize() {
    _crop.style.width = '${size.x}px';
    _crop.style.height = '${size.y}px';
  }

  void setPosAndSize(Point p, Point s) {
    p = p.cast<double>();
    s = s.cast<double>();
    final oldZero = _grid.zero;
    final oldSize = _grid.size;
    _grid.zero = clamp(p, Point(0, 0), _imgSize - size.cast<double>());
    _grid.size = clamp(s, minSize, _imgSize - offset.cast<double>());
    _grid.zero = clamp(p, Point(0, 0), _imgSize - size.cast<double>());

    if (_grid.zero != oldZero) _applyZero();
    if (_grid.size != oldSize) _applySize();
    if (_grid.size.x != oldSize.x) _applyCellSize();
    _repositionMovables();
    redrawCanvas();
  }

  void _applyCellSize() {
    user.session!.board.applyCellSize();
    if (_grid is UnclampedGrid) {
      (_grid as UnclampedGrid).scale = tokenSize;
    }
    user.session!.board.transform.applyInvZoom();
    updateCanvasSvgTile();
  }

  Point offsetToGridSpaceUnscaled(
    Point point, {
    Point offset = const Point(0.5, 0.5),
  }) {
    final cOffset = offset.cast<double>();
    final p = _grid.worldToGridSpace(point.cast<double>() - cOffset) - cOffset;
    return p;
  }

  Point centeredWorldPoint(Point center, int size) {
    return grid.worldSnapCentered(center, size);
  }

  void resetPosAndSize(int width, int height) {
    setPosAndSize(Point(0, 0), Point(width.toDouble(), height.toDouble()));
  }

  void constrainSize(int width, int height) {
    if (offset.x + size.x > width || offset.y + size.y > height) {
      resetPosAndSize(width, height);
    }
  }

  static String _patternId(int gridType) {
    switch (gridType) {
      case GRID_SQUARE:
        return '#gridPatternSquare';
      case GRID_HEX_H:
        return '#gridPatternHexH';
      case GRID_HEX_V:
        return '#gridPatternHexV';
    }
    return '';
  }

  void redrawCanvas() {
    var patternId = _patternId(gridType);
    var fill = gridType == GRID_NONE ? 'none' : 'url($patternId)';
    _rect.setAttribute('fill', fill);

    if (gridType == GRID_NONE) return;

    var pattern = queryDom(patternId);
    var scale = cellWidth;
    pattern.setAttribute(
      'patternTransform',
      'translate(${offset.x}, ${offset.y}) scale($scale)',
    );

    var patternG = pattern.children.first;
    patternG.setAttribute('stroke', _gridColor.value!);
    patternG.setAttribute('opacity', _gridAlpha.value!);
  }

  void configure({
    required int gridType,
    required int tiles,
    required String tileUnit,
    required String color,
    required double alpha,
    required Point position,
    Point? size,
  }) {
    _gridType = gridType;
    _grid = _createGrid(
        gridType, tiles, position, (size ?? _imgSize).cast<double>());

    _gridTileUnit.value = tileUnit;
    _validateTileUnit();
    _gridColor.value = color;
    _gridAlpha.valueAsNumber = alpha;
    _applyGrid(tiles);
  }

  Map<String, dynamic> toJson() => {
        'type': _gridType,
        'offset': writePoint(offset),
        'size': writePoint(size),
        'tiles': tiles,
        'tileUnit': _gridTileUnit.value,
        'color': _gridColor.value,
        'alpha': _gridAlpha.valueAsNumber,
      };

  void fromJson(Map<String, dynamic> json) {
    configure(
      gridType: json['type'],
      tiles: json['tiles'],
      tileUnit: json['tileUnit'],
      color: json['color'],
      alpha: json['alpha'],
      position: parsePoint(json['offset'])!,
      size: parsePoint(json['size']),
    );
  }
}
