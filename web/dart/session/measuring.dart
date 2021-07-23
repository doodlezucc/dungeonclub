import 'dart:html';
import 'dart:math';
import 'dart:svg' as svg;

import 'package:web_whiteboard/util.dart';

import '../../main.dart';

const MEASURING_PATH = 0;
const MEASURING_CIRCLE = 1;

final svg.SvgSvgElement measuringRoot = querySelector('#distanceCanvas');

abstract class Measuring {
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

  static Measuring create(int type, Point origin) {
    switch (type) {
      case MEASURING_PATH:
        return MeasuringPath(origin);
      case MEASURING_CIRCLE:
        return MeasuringCircle(origin);
    }
    return null;
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

  void _applyCircle(svg.CircleElement elem, Point p) {
    elem.setAttribute('cx', '${p.x}');
    elem.setAttribute('cy', '${p.y}');
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

class MeasuringCircle extends Measuring {
  final _squares = svg.GElement();
  final _center = svg.CircleElement();
  double _bufferedRadius = -1;

  MeasuringCircle(Point origin) : super(origin, svg.CircleElement()) {
    _applyCircle(_e..classes.add('sphere'), origin);
    _applyCircle(_center..setAttribute('r', '0.2'), origin);
    measuringRoot.insertAllBefore([_center, _squares], _e);
  }

  void _applyCircle(svg.CircleElement elem, Point p) {
    elem.setAttribute('cx', '${p.x}');
    elem.setAttribute('cy', '${p.y}');
  }

  @override
  void dispose() {
    super.dispose();
    _squares.remove();
    _center.remove();
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
