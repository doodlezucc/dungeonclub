import 'dart:html';
import 'dart:math';
import 'dart:svg' as svg;

import 'package:web_whiteboard/util.dart';

import '../../main.dart';

final svg.SvgSvgElement measuringRoot = querySelector('#distanceCanvas');
final HtmlElement distanceText = querySelector('#distanceText');
const _stopRadius = 0.2;

class MeasuringPath {
  final e = svg.PathElement();
  final lastE = svg.CircleElement()..setAttribute('r', '$_stopRadius');
  final stops = <svg.CircleElement>[];
  final points = <Point<int>>[];
  double previousDistance = 0;

  MeasuringPath() {
    measuringRoot..append(e)..append(lastE);
    distanceText.classes.remove('hidden');
  }

  void dispose() {
    e.remove();
    stops.forEach((e) => e.remove());
    lastE.remove();
    distanceText.classes.add('hidden');
  }

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

  void redraw(Point extra) {
    var end = forceIntPoint(extra);
    e.setAttribute('d', _toPathData(end));
    _applyCircle(lastE, end);
    _updateDistanceText(end);
  }

  void _updateDistanceText(Point<int> end) {
    var total = previousDistance + _lastSegmentLength(end);
    distanceText.text = user.session.board.grid.tileUnitString(total);
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
