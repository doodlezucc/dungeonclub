import 'dart:html';
import 'dart:math';
import 'dart:svg' as svg;
import 'dart:typed_data';

import 'package:web_whiteboard/binary.dart';
import 'package:web_whiteboard/util.dart';

import '../../main.dart';
import '../communication.dart';

const MEASURING_PATH = 0;
const MEASURING_CIRCLE = 1;
const MEASURING_CONE = 2;
const MEASURING_CUBE = 3;
const MEASURING_LINE = 4;

const measuringPort = 80;
const _precision = 63;
final Map<int, Measuring> _pcMeasurings = {};

final HtmlElement _toolbox = querySelector('#measureTools');
final svg.SvgSvgElement measuringRoot = querySelector('#measureCanvas');
final svg.SvgSvgElement distanceRoot = querySelector('#distanceCanvas');
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
      user.session.board.zoom += 0; // Rescale distance text
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

  final svg.SvgElement _e;
  final HtmlElement _distanceText;
  final Point origin;
  final String color;

  Measuring(this.origin, this._e, int pc, [svg.SvgElement root])
      : _distanceText = SpanElement(),
        color = user.session.getPlayerColor(pc) {
    _pcMeasurings[pc]?.dispose();
    _pcMeasurings[pc] = this;
    root ??= measuringRoot;
    root.append(_e);
    querySelector('#board').append(_distanceText..className = 'distance-text');
    redraw(origin);
  }

  void dispose() {
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
    alignDistanceText(extra * user.session.board.grid.cellSize);
    if (handleSpecifics(reader)) return;
    redraw(extra);
  }

  void writeSpecifics(BinaryWriter writer) {}
  bool handleSpecifics(BinaryReader reader) => false;
}

class MeasuringPath extends Measuring {
  static const _stopRadius = 0.2;

  final path = svg.PathElement();
  final lastE = svg.CircleElement()..setAttribute('r', '$_stopRadius');
  final points = <Point<int>>[];
  int pointsSinceSync = 0;
  double previousDistance = 0;

  MeasuringPath(Point origin, int pc, {bool background = false})
      : super(origin, svg.GElement(), pc,
            background ? distanceRoot : measuringRoot) {
    _e.setAttribute(
        'transform', 'translate(${origin.x % 1.0}, ${origin.y % 1.0})');
    _e
      ..append(path)
      ..append(lastE);
    addPoint(origin);
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

  @override
  void addPoint(Point point) {
    var p = forceIntPoint(point);

    var stop = svg.CircleElement()..setAttribute('r', '$_stopRadius');
    _applyCircle(stop, p);
    _e.append(stop);

    previousDistance += _lastSegmentLength(p);
    points.add(p);
    pointsSinceSync++;
    redraw(p);
  }

  double _lastSegmentLength(Point<int> end) {
    if (points.isEmpty) return 0;
    // Chebychov distance
    var distance = max(
      (end.x - points.last.x).abs(),
      (end.y - points.last.y).abs(),
    );
    return distance.toDouble();
  }

  @override
  void redraw(Point extra) {
    var end = forceIntPoint(extra);
    path.setAttribute('d', _toPathData(end));
    _applyCircle(lastE, end);
    _updateDistanceText(end);
  }

  void _updateDistanceText(Point<int> end) {
    var total = previousDistance + _lastSegmentLength(end);
    updateDistanceText(total);
  }

  String _toPathData(Point<int> end) {
    if (points.isEmpty) return '';

    String writePoint(Point<int> p) {
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

abstract class CoveredMeasuring extends Measuring {
  final _center = svg.CircleElement();
  final _squares = svg.GElement();

  CoveredMeasuring(Point origin, svg.SvgElement elem, int pc)
      : super(origin, elem, pc) {
    _applyCircle(_center..setAttribute('r', '0.25'), origin);
    measuringRoot.insertBefore(_squares..setAttribute('fill', '${color}60'),
        _e..classes.add('no-fill'));
    measuringRoot.append(_center);
  }

  @override
  void dispose() {
    super.dispose();
    _center.remove();
    _squares.remove();
  }
}

class MeasuringCircle extends CoveredMeasuring {
  double _bufferedRadius = -1;

  MeasuringCircle(Point origin, int pc)
      : super(origin, svg.CircleElement(), pc) {
    _applyCircle(_e, origin);
  }

  @override
  void redraw(Point extra) {
    var distance = origin.distanceTo(extra).roundToDouble();

    if (distance == _bufferedRadius) return;
    _bufferedRadius = distance;

    _e.setAttribute('r', '$distance');
    updateDistanceText(distance);
    _updateSquares(distance);
  }

  void _updateSquares(double radius) {
    _squares.children.clear();
    for (var x = -radius - origin.x % 1; x < radius; x++) {
      for (var y = -radius - origin.y % 1; y < radius; y++) {
        if ((x * x + y * y) < radius * radius) {
          _squares.append(svg.RectElement()
            ..setAttribute('x', '${origin.x + x - 0.5}')
            ..setAttribute('y', '${origin.y + y - 0.5}'));
        }
      }
    }
  }
}

class MeasuringCone extends CoveredMeasuring {
  double lockedRadius;
  bool lockRadius = false;

  MeasuringCone(Point origin, int pc)
      : super(forceDoublePoint(origin), svg.PolygonElement(), pc);

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
  void redraw(Point extra) {
    var distance = lockRadius
        ? lockedRadius
        : origin.distanceTo(forceDoublePoint(extra)).roundToDouble();

    if (!lockRadius) {
      lockedRadius = distance;
    }

    if (distance > 0) {
      var vec = forceDoublePoint(extra) - origin;
      var rounded = vec * (distance / vec.distanceTo(Point(0, 0)));

      var p1 = origin + rounded + Point<double>(-rounded.y / 2, rounded.x / 2);
      var p2 = origin + rounded + Point<double>(rounded.y / 2, -rounded.x / 2);

      _e.setAttribute(
          'points', '${_toSvg(origin)} ${_toSvg(p1)} ${_toSvg(p2)}');
      _updateSquares(p1, p2, distance);
    } else {
      _e.setAttribute('points', '');
      _squares.children.clear();
    }

    updateDistanceText(distance);
  }

  static String _toSvg(Point p) => '${p.x},${p.y}';

  void _updateSquares(Point<double> p1, Point<double> p2, double distance) {
    Point<int> fixPoint(Point p) =>
        Point((p.x + 0.5).floor(), (p.y + 0.5).floor());

    var affected = <Point<int>>{};
    var lengthStep = 0.3;

    for (var w = 0.0; w <= 1; w += 0.2 / distance) {
      var q = p1 + (p2 - p1) * w;
      var vec = (q - origin) * (lengthStep / distance);

      var p = origin + vec;

      for (var l = lengthStep; l < distance; l += lengthStep) {
        affected.add(fixPoint(p));
        p += vec;
      }
    }

    _squares.children.clear();
    for (var p in affected) {
      _squares.append(svg.RectElement()
        ..setAttribute('x', '${p.x - 0.5}')
        ..setAttribute('y', '${p.y - 0.5}'));
    }
  }
}

class MeasuringCube extends CoveredMeasuring {
  MeasuringCube(Point origin, int pc) : super(origin, svg.RectElement(), pc);

  @override
  void redraw(Point extra) {
    var distance = max((extra.x - origin.x).abs(), (extra.y - origin.y).abs())
        .roundToDouble();

    var signed = Point((extra.x - origin.x).sign * distance,
        (extra.y - origin.y).sign * distance);
    var rect = Rectangle.fromPoints(
        origin, forceDoublePoint(origin) + forceDoublePoint(signed));

    _e
      ..setAttribute('x', '${rect.left}')
      ..setAttribute('y', '${rect.top}')
      ..setAttribute('width', '${rect.width}')
      ..setAttribute('height', '${rect.height}');
    _updateSquares(rect);

    updateDistanceText(distance);
  }

  void _updateSquares(Rectangle rect) {
    _squares.children.clear();

    for (var x = rect.left; x < rect.right; x++) {
      for (var y = rect.top; y < rect.bottom; y++) {
        _squares.append(svg.RectElement()
          ..setAttribute('x', '$x')
          ..setAttribute('y', '$y'));
      }
    }
  }
}

class MeasuringLine extends CoveredMeasuring {
  Point endBuffered;
  double width = _bufferedLineWidth;
  bool changeWidth = false;

  MeasuringLine(Point origin, int pc)
      : super(forceDoublePoint(origin), svg.PolygonElement(), pc);

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
    _update(endBuffered);
    return true;
  }

  @override
  void redraw(Point extra) {
    if (!changeWidth) {
      _update(extra);
    } else {
      var distance =
          endBuffered.distanceTo(forceDoublePoint(extra)).roundToDouble();
      width = distance;
      _bufferedLineWidth = distance;
      _update(endBuffered);
    }
  }

  void _update(Point extra) {
    extra = forceDoublePoint(extra);
    var distance = origin.distanceTo(extra).roundToDouble();
    distance = max(0, distance - 1);

    if (distance > 0) {
      var vec = forceDoublePoint(extra - origin);
      var norm = vec * (1 / vec.distanceTo(Point(0, 0)));
      var end = origin + norm * distance;
      var right = Point(-norm.y, norm.x) * (width / 2);

      var p1 = origin + right;
      var p2 = end + right;
      var q1 = origin - right;
      var q2 = end - right;

      _e.setAttribute(
          'points', '${_toSvg(p1)} ${_toSvg(p2)} ${_toSvg(q2)} ${_toSvg(q1)}');
      _updateSquares(norm, right, distance);
    } else {
      _e.setAttribute('points', '');
      _squares.children.clear();
    }

    endBuffered = extra;
    updateDistanceText(changeWidth ? width : distance);
  }

  static String _toSvg(Point p) => '${p.x},${p.y}';

  void _updateSquares(Point norm, Point right, double distance) {
    Point<int> fixPoint(Point p) =>
        Point((p.x + 0.5).floor(), (p.y + 0.5).floor());

    var affected = <Point<int>>{};
    var lengthStep = 1;

    for (var w = -1.0; w <= 1; w += 0.5 / width) {
      var p = origin + right * w;

      for (var l = 0; l <= distance; l += lengthStep) {
        affected.add(fixPoint(p));
        p += norm * lengthStep;
      }
    }

    _squares.children.clear();
    for (var p in affected) {
      _squares.append(svg.RectElement()
        ..setAttribute('x', '${p.x - 0.5}')
        ..setAttribute('y', '${p.y - 0.5}'));
    }
  }
}

void _applyCircle(svg.CircleElement elem, Point p) {
  elem.setAttribute('cx', '${p.x}');
  elem.setAttribute('cy', '${p.y}');
}
