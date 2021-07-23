import 'dart:html';
import 'dart:math';
import 'dart:svg' as svg;

import 'package:web_whiteboard/util.dart';

import '../../main.dart';

final svg.SvgSvgElement measuringRoot = querySelector('#distanceCanvas');

abstract class Measuring {
  final svg.SvgElement _e;
  final HtmlElement _distanceText;

  Measuring(this._e) : _distanceText = SpanElement() {
    measuringRoot.append(_e);
    measuringRoot.parent.append(_distanceText..className = 'distance-text');
  }

  void dispose() {
    _e.remove();
    _distanceText.remove();
  }

  void addPoint(Point point);
  void redraw(Point extra);

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

  MeasuringPath() : super(svg.PathElement()) {
    measuringRoot.append(lastE);
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
