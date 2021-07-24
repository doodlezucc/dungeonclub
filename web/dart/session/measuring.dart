import 'dart:html';
import 'dart:math';
import 'dart:svg' as svg;

import 'package:web_whiteboard/util.dart';

import '../../main.dart';

const MEASURING_PATH = 0;
const MEASURING_CIRCLE = 1;
const MEASURING_CONE = 2;
const MEASURING_CUBE = 3;

final HtmlElement _toolbox = querySelector('#measureTools');
final svg.SvgSvgElement measuringRoot = querySelector('#distanceCanvas');

int _measureMode;
int get measureMode => _measureMode;
set measureMode(int measureMode) {
  _measureMode = measureMode;
  _toolbox.querySelectorAll('.active').classes.remove('active');
  _toolbox.querySelector('[mode="$measureMode"]').classes.add('active');
}

abstract class Measuring {
  static Measuring create(int type, Point origin) {
    switch (type) {
      case MEASURING_PATH:
        return MeasuringPath(origin);
      case MEASURING_CIRCLE:
        return MeasuringCircle(origin);
      case MEASURING_CONE:
        return MeasuringCone(origin);
      case MEASURING_CUBE:
        return MeasuringCube(origin);
    }
    return null;
  }

  final svg.SvgElement _e;
  final HtmlElement _distanceText;
  final Point origin;

  Measuring(this.origin, this._e) : _distanceText = SpanElement() {
    measuringRoot.append(_e);
    measuringRoot.parent.append(_distanceText..className = 'distance-text');
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
}

class MeasuringPath extends Measuring {
  static const _stopRadius = 0.2;

  final lastE = svg.CircleElement()..setAttribute('r', '$_stopRadius');
  final stops = <svg.CircleElement>[];
  final points = <Point<int>>[];
  double previousDistance = 0;

  MeasuringPath(Point origin) : super(origin, svg.PathElement()) {
    measuringRoot.append(lastE);
    addPoint(origin);
  }

  @override
  void dispose() {
    super.dispose();
    stops.forEach((e) => e.remove());
    lastE.remove();
  }

  @override
  void addPoint(Point point) {
    var p = forceIntPoint(point);

    var stop = svg.CircleElement()..setAttribute('r', '$_stopRadius');
    _applyCircle(stop, p);
    measuringRoot.append(stop);
    stops.add(stop);

    previousDistance += _lastSegmentLength(p);
    points.add(p);
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
    _e.setAttribute('d', _toPathData(end));
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

  CoveredMeasuring(Point origin, svg.SvgElement elem) : super(origin, elem) {
    _applyCircle(_center..setAttribute('r', '0.25'), origin);
    measuringRoot.insertBefore(_squares, _e..classes.add('no-fill'));
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

  MeasuringCircle(Point origin) : super(origin, svg.CircleElement()) {
    _applyCircle(_e, origin);
  }

  @override
  void redraw(Point extra) {
    var distance = origin.distanceTo(extra).roundToDouble();

    if (distance == _bufferedRadius) return;
    _bufferedRadius = distance;

    _e.setAttribute('r', '$distance');
    alignDistanceText(extra);
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

  MeasuringCone(Point origin) : super(origin, svg.PolygonElement());

  @override
  void addPoint(Point<num> point) {
    lockRadius = !lockRadius;
  }

  @override
  void redraw(Point extra) {
    var distance =
        lockRadius ? lockedRadius : origin.distanceTo(extra).roundToDouble();

    if (!lockRadius) {
      lockedRadius = distance;
    }

    if (distance > 0) {
      var vec = extra - origin;
      var rounded = vec * (distance / vec.distanceTo(Point(0, 0)));

      var p1 = origin + rounded + Point(-rounded.y / 2, rounded.x / 2);
      var p2 = origin + rounded + Point(rounded.y / 2, -rounded.x / 2);

      _e.setAttribute(
          'points', '${_toSvg(origin)} ${_toSvg(p1)} ${_toSvg(p2)}');
      _updateSquares(p1, p2, distance);
    } else {
      _e.setAttribute('points', '');
      _squares.children.clear();
    }

    alignDistanceText(extra);
    updateDistanceText(distance);
  }

  static String _toSvg(Point p) => '${p.x},${p.y}';

  void _updateSquares(Point p1, Point p2, double distance) {
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
  MeasuringCube(Point origin) : super(origin, svg.RectElement());

  @override
  void redraw(Point extra) {
    var distance = max((extra.x - origin.x).abs(), (extra.y - origin.y).abs())
        .roundToDouble();

    var signed = Point((extra.x - origin.x).sign * distance,
        (extra.y - origin.y).sign * distance);
    var rect = Rectangle.fromPoints(origin, origin + signed);

    _e
      ..setAttribute('x', '${rect.left}')
      ..setAttribute('y', '${rect.top}')
      ..setAttribute('width', '${rect.width}')
      ..setAttribute('height', '${rect.height}');
    _updateSquares(rect);

    alignDistanceText(extra);
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

void _applyCircle(svg.CircleElement elem, Point p) {
  elem.setAttribute('cx', '${p.x}');
  elem.setAttribute('cy', '${p.y}');
}
