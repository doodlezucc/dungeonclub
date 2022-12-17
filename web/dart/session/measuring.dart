import 'dart:html';
import 'dart:svg' as svg;
import 'dart:typed_data';

import 'package:dungeonclub/measuring/area_of_effect.dart';
import 'package:dungeonclub/shape_painter/painter.dart';
import 'package:dungeonclub/shape_painter/svg_painter.dart';
import 'package:dungeonclub/measuring/ruleset.dart';
import 'package:grid/grid.dart';
import 'package:web_whiteboard/binary.dart';
import 'package:web_whiteboard/util.dart';

import '../../main.dart';
import '../communication.dart';
import 'grid.dart';

const MEASURING_PATH = 0;
const MEASURING_CIRCLE = 1;
const MEASURING_CONE = 2;
const MEASURING_CUBE = 3;
const MEASURING_LINE = 4;

const measuringPort = 80;
const _precision = 63;
final Map<int, Measuring> _pcMeasurings = {};

final HtmlElement _toolbox = querySelector('#measureTools');
final svg.SvgSvgElement _measuringRoot = querySelector('#measureCanvas');
final svg.PolygonElement _measuringTile = _measuringRoot.querySelector('#tile');
final svg.SvgSvgElement _distanceRoot = querySelector('#distanceCanvas');
double _bufferedLineWidth = 1;

int _measureMode;
int get measureMode => _measureMode;
set measureMode(int measureMode) {
  _measureMode = measureMode;
  _toolbox.querySelectorAll('.active').classes.remove('active');
  _toolbox.querySelector('[mode="$measureMode"]').classes.add('active');
}

String getMeasureTooltip() {
  switch (measureMode) {
    case MEASURING_PATH:
      return '''Hold *left click* to draw a path. *Rightclick* to add corners.
                <br>Hold *shift* to start at an intersection of squares.''';
    case MEASURING_CIRCLE:
      return '''*Leftclick* an intersection and drag outwards
                to draw a <br>circular
                shape. Hold *shift* to start at a square's center.''';
    case MEASURING_CONE:
      return '''*Leftclick* an intersection and drag outwards to visualize
                a cone.<br>*Rightclick* to lock its radius.
                Hold *shift* to start at a square's center.''';
    case MEASURING_CUBE:
      return '''*Leftclick* an intersection and drag outwards
                to draw a cube.''';
    case MEASURING_LINE:
      return '''Hold *left click* to draw a line of specified width.
                *Rightclick* to switch to<br>width modification.
                Hold *shift* to start at a square's center.''';
  }
  return '';
}

void updateCanvasSvgTile() {
  final grid = Measuring.getGrid().grid;
  _measuringTile.points.clear();

  if (grid is TiledGrid) {
    for (var point in grid.tileShape.points) {
      final p = Point(point.x * grid.tileWidth, point.y * grid.tileWidth);
      _measuringTile.points.appendItem(_measuringRoot.createSvgPoint()
        ..x = p.x
        ..y = p.y);
    }
  }
}

void _writePrecision(BinaryWriter writer, Point p) {
  var point = p * _precision;
  writer.writePoint(Point(point.x.round(), point.y.round()));
}

Point _readPrecision(BinaryReader reader) {
  return forceDoublePoint(reader.readPoint()) * (1 / _precision);
}

void sendCreationEvent(int type, Point origin, Point p) {
  var writer = BinaryWriter();
  writer.writeUInt8(measuringPort);
  writer.writeUInt8(user.session.charId ?? 255);
  writer.writeUInt8(0); // Creation event
  writer.writeUInt8(type);
  _writePrecision(writer, origin);
  writer.writePoint(forceIntPoint(p));

  socket.send(writer.takeBytes());
}

void removeMeasuring(int pc, {bool sendEvent = false}) {
  var m = _pcMeasurings.remove(pc);
  if (m != null) {
    m.dispose();
    if (sendEvent) m.sendRemovalEvent();
  }
}

void handleMeasuringEvent(Uint8List bytes) {
  var reader = BinaryReader.fromList(bytes)..readUInt8(); // Skip port byte

  var pc = reader.readUInt8();
  if (pc == 255) pc = null;

  var event = reader.readUInt8();

  switch (event) {
    case 0:
      var m = Measuring.create(reader.readUInt8(), _readPrecision(reader), pc);
      m.alignDistanceText(reader.readPoint());
      user.session.board.transform.applyInvZoom(); // Rescale distance text
      return;
    case 1:
      return _pcMeasurings[pc]?.handleUpdateEvent(reader);
    case 2:
      return removeMeasuring(pc);
  }
}

abstract class Measuring {
  static Measuring create(int type, Point origin, int player) {
    if (player == 255) player = null; // Reset GM color

    switch (type) {
      case MEASURING_PATH:
        return MeasuringPath(origin, player);
      case MEASURING_CIRCLE:
        return MeasuringCircle(origin, player);
      case MEASURING_CONE:
        return MeasuringCone(origin, player);
      case MEASURING_CUBE:
        return MeasuringCube(origin, player);
      case MEASURING_LINE:
        return MeasuringLine(origin, player);
    }
    return null;
  }

  final svg.GElement _e;
  final HtmlElement _distanceText;
  final Point<double> origin;
  final String color;
  int snapSize;

  Measuring(Point origin, this._e, int pc, [svg.SvgElement root])
      : origin = origin.cast<double>(),
        _distanceText = SpanElement(),
        color = user.session.getPlayerColor(pc) {
    _pcMeasurings[pc]?.dispose();
    _pcMeasurings[pc] = this;
    root ??= _measuringRoot;
    root.append(_e);
    user.session.board.transform.registerInvZoom(_distanceText);
    querySelector('#board').append(_distanceText..className = 'distance-text');
  }

  static SceneGrid getGrid() {
    return user.session.board.grid;
  }

  void dispose() {
    user.session.board.transform.unregisterInvZoom(_distanceText);
    _e.remove();
    _distanceText.remove();
  }

  void redraw(Point extra);
  void addPoint(Point point) {}

  void alignDistanceText(Point p) {
    _distanceText.style.left = '${p.x}px';
    _distanceText.style.top = '${p.y}px';
  }

  void updateDistanceText(double distance) {
    _distanceText.text = user.session.board.grid.tileUnitString(distance);
  }

  void sendUpdateEvent(Point extra) {
    var writer = BinaryWriter();
    writer.writeUInt8(measuringPort);
    writer.writeUInt8(user.session.charId ?? 255);
    writer.writeUInt8(1); // Update event
    _writePrecision(writer, extra);
    writeSpecifics(writer);
    socket.send(writer.takeBytes());
  }

  void sendRemovalEvent() {
    var writer = BinaryWriter();
    writer.writeUInt8(measuringPort);
    writer.writeUInt8(user.session.charId ?? 255);
    writer.writeUInt8(2); // Removal event
    socket.send(writer.takeBytes());
  }

  void handleUpdateEvent(BinaryReader reader) {
    var extra = _readPrecision(reader);
    alignDistanceText(extra * user.session.board.grid.cellWidth);
    if (handleSpecifics(reader)) return;
    redraw(extra);
  }

  void writeSpecifics(BinaryWriter writer) {}
  bool handleSpecifics(BinaryReader reader) => false;
}

class MeasuringPath extends Measuring {
  final path = svg.PathElement();
  final lastE = svg.CircleElement()..classes.add('origin');
  final points = <Point>[];
  final int size;
  int pointsSinceSync = 0;
  double previousDistance = 0;

  MeasuringPath(
    Point origin,
    int pc, {
    bool background = false,
    this.size = 1,
  }) : super(origin, svg.GElement(), pc,
            background ? _distanceRoot : _measuringRoot) {
    _e
      ..append(path)
      ..append(lastE);
    addPoint(origin);

    if (background) {
      _distanceText.classes.add('slow');
    }
  }

  @override
  void writeSpecifics(BinaryWriter writer) {
    writer.writeUInt8(pointsSinceSync);
    for (var i = pointsSinceSync; i > 0; i--) {
      _writePrecision(writer, points[points.length - i]);
    }
    pointsSinceSync = 0;
  }

  @override
  bool handleSpecifics(BinaryReader reader) {
    var nPoints = reader.readUInt8();
    for (var i = 0; i < nPoints; i++) {
      addPoint(_readPrecision(reader));
    }
    return false;
  }

  Point snapped(Point p) {
    return Measuring.getGrid().grid.gridSnapCentered(p, size);
  }

  @override
  void addPoint(Point p) {
    p = snapped(p);
    var stop = svg.CircleElement()..classes.add('origin');
    _applyCircleGridToWorld(stop, p);
    _e.append(stop);

    previousDistance += _lastSegmentLength(p);
    points.add(p);
    pointsSinceSync++;
    redraw(p, doSnap: false);
  }

  double _lastSegmentLength(Point end) {
    if (points.isEmpty) return 0;

    final distance = Measuring.getGrid()
        .measuringRuleset
        .distanceBetweenGridPoints(Measuring.getGrid().grid, points.last, end);
    return distance.toDouble();
  }

  @override
  void redraw(Point end, {bool doSnap = true}) {
    if (doSnap) {
      end = snapped(end);
    }
    path.setAttribute('d', _toPathData(end));
    _applyCircleGridToWorld(lastE, end);
    _updateDistanceText(end);
  }

  void _updateDistanceText(Point end) {
    var total = previousDistance + _lastSegmentLength(end);
    updateDistanceText(total);
  }

  String _toPathData(Point end) {
    if (points.isEmpty) return '';

    String writePoint(Point ps) {
      final p = Measuring.getGrid().grid.gridToWorldSpace(ps);
      return ' ${p.x} ${p.y}';
    }

    var s = 'M' + writePoint(points.first);

    for (var p in points) {
      s += ' L' + writePoint(p);
    }

    s += ' L' + writePoint(end);

    return s;
  }
}

abstract class CoveredMeasuring<T extends AreaOfEffectTemplate>
    extends Measuring {
  final _center = svg.CircleElement()..classes.add('origin');
  final _tiles = svg.GElement();
  T _aoe;

  CoveredMeasuring(Point origin, int pc) : super(origin, svg.GElement(), pc) {
    _applyCircleGridToWorld(_center, origin);

    final grid = Measuring.getGrid();
    final tilesTransform =
        'translate(-${grid.cellWidth / 2} -${grid.cellHeight / 2})';

    _tiles
      ..setAttribute('transform', tilesTransform)
      ..setAttribute('fill', '${color}60');
    _e
      ..append(_tiles)
      ..append(_center);

    _measuringRoot.append(_e);

    final transform = PaintTransform(
      grid.offset.cast<double>(),
      grid.cellSize.cast<double>(),
    );
    final painter = SvgShapePainter(_e, transform);
    _aoe = createAoE(grid.measuringRuleset, painter, grid.grid);
    redraw(origin);
  }

  @override
  void redraw(Point extra) {
    final extraCast = extra.cast<double>();
    final sceneGrid = Measuring.getGrid();
    final grid = sceneGrid.grid;
    final ruleset = sceneGrid.measuringRuleset;

    double distance =
        ruleset.distanceBetweenGridPoints(grid, origin, extraCast);

    var tileDistance = _aoe.distanceMultiplier;
    if (grid is TiledGrid) {
      if (grid is HexagonalGrid) {
        tileDistance *= grid.tileDistance;
        distance /= tileDistance;
      }
      distance = distance.roundToDouble();
    }

    updateDistanceText(distance);

    final areaChanged = _aoe.onMove(extraCast, distance * tileDistance);
    if (areaChanged) {
      _updateTiles();
    }
  }

  @override
  void dispose() {
    super.dispose();
    _center.remove();
    _tiles.remove();
  }

  void _updateTiles() {
    _tiles.children.clear();
    final tiles = _aoe.getAffectedTiles();
    for (var tile in tiles) {
      final gridPos = (_aoe.grid as TiledGrid).tileCenterInWorld(tile);
      _tiles.append(svg.UseElement()
        ..setAttribute('href', '#tile')
        ..setAttribute('transform', 'translate(${gridPos.x} ${gridPos.y})'));
    }
  }

  T createAoE(MeasuringRuleset ruleset, ShapePainter painter, Grid grid) {
    throw UnimplementedError();
  }
}

class MeasuringCircle extends CoveredMeasuring<SphereAreaOfEffect> {
  MeasuringCircle(Point<num> origin, int pc) : super(origin, pc);

  @override
  SphereAreaOfEffect<Grid> createAoE(
          covariant SupportsSphere ruleset, ShapePainter painter, Grid grid) =>
      ruleset.aoeSphere(origin, painter, grid);
}

class MeasuringCube extends CoveredMeasuring<CubeAreaOfEffect> {
  MeasuringCube(Point origin, int pc) : super(origin, pc);

  @override
  CubeAreaOfEffect<Grid> createAoE(
          covariant SupportsCube ruleset, ShapePainter painter, Grid grid) =>
      ruleset.aoeCube(origin, painter, grid);
}

class MeasuringCone extends CoveredMeasuring {
  double lockedRadius = 0;
  bool lockRadius = false;

  MeasuringCone(Point origin, int pc) : super(forceDoublePoint(origin), pc);

  @override
  void redraw(Point extra) {
    super.redraw(extra);
    lockedRadius = (_aoe as ConeAreaOfEffect).distance;
  }

  @override
  void addPoint(Point<num> point) {
    lockRadius = !lockRadius;
  }

  @override
  void writeSpecifics(BinaryWriter writer) {
    writer.writeUInt8(lockedRadius.toInt());
  }

  @override
  bool handleSpecifics(BinaryReader reader) {
    lockRadius = true;
    lockedRadius = reader.readUInt8().toDouble();
    return false;
  }

  @override
  ConeAreaOfEffect createAoE(
          covariant SupportsCone ruleset, ShapePainter painter, Grid grid) =>
      ruleset.aoeCone(origin, painter, grid);
}

class MeasuringLine extends CoveredMeasuring {
  Point endBuffered;
  double width = _bufferedLineWidth;
  bool changeWidth = false;

  MeasuringLine(Point origin, int pc) : super(forceDoublePoint(origin), pc);

  @override
  void addPoint(Point<num> point) {
    changeWidth = !changeWidth;
  }

  @override
  void writeSpecifics(BinaryWriter writer) {
    _writePrecision(writer, endBuffered);
    writer.writeUInt8(width.round());
  }

  @override
  bool handleSpecifics(BinaryReader reader) {
    endBuffered = _readPrecision(reader);
    width = reader.readUInt8().toDouble();
    changeWidth = false;
    // _update(endBuffered);
    return true;
  }

  // @override
  // void redraw(Point extra) {
  //   if (!changeWidth) {
  //     _update(extra);
  //   } else {
  //     var distance =
  //         endBuffered.distanceTo(forceDoublePoint(extra)).roundToDouble();
  //     width = distance;
  //     _bufferedLineWidth = distance;
  //     _update(endBuffered);
  //   }
  // }

  // void _update(Point extra) {
  //   extra = forceDoublePoint(extra);
  //   var distance = origin.distanceTo(extra).roundToDouble();
  //   distance = max(0, distance - 1);

  //   if (distance > 0) {
  //     var vec = forceDoublePoint(extra - origin);
  //     var norm = vec * (1 / vec.distanceTo(Point(0, 0)));
  //     var end = origin + norm * distance;
  //     var right = Point(-norm.y, norm.x) * (width / 2);

  //     var p1 = origin + right;
  //     var p2 = end + right;
  //     var q1 = origin - right;
  //     var q2 = end - right;

  //     _e.setAttribute(
  //         'points', '${_toSvg(p1)} ${_toSvg(p2)} ${_toSvg(q2)} ${_toSvg(q1)}');
  //     _updateSquares(norm, right, distance);
  //   } else {
  //     _e.setAttribute('points', '');
  //     _squares.children.clear();
  //   }

  //   endBuffered = extra;
  //   updateDistanceText(changeWidth ? width : distance);
  // }

  // static String _toSvg(Point p) => '${p.x},${p.y}';

  // void _updateSquares(Point norm, Point right, double distance) {
  //   Point<int> fixPoint(Point p) =>
  //       Point((p.x + 0.5).floor(), (p.y + 0.5).floor());

  //   var affected = <Point<int>>{};
  //   var lengthStep = 1;

  //   for (var w = -1.0; w <= 1; w += 0.5 / width) {
  //     var p = origin + right * w;

  //     for (var l = 0; l <= distance; l += lengthStep) {
  //       affected.add(fixPoint(p));
  //       p += norm * lengthStep;
  //     }
  //   }

  //   _squares.children.clear();
  //   for (var p in affected) {
  //     _squares.append(svg.RectElement()
  //       ..setAttribute('x', '${p.x - 0.5}')
  //       ..setAttribute('y', '${p.y - 0.5}'));
  //   }
  // }
}

void _applyCircle(svg.CircleElement elem, Point p) {
  elem.setAttribute('cx', '${p.x}');
  elem.setAttribute('cy', '${p.y}');
}

void _applyCircleGridToWorld(svg.CircleElement elem, Point p) {
  _applyCircle(elem, Measuring.getGrid().grid.gridToWorldSpace(p));
}
