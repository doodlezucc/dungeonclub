import 'dart:math';

Point parsePoint(dynamic json) {
  return json == null ? null : Point(json['x'], json['y']);
}

Map<String, dynamic> writePoint(Point point) => point != null
    ? {
        'x': point.x,
        'y': point.y,
      }
    : null;

Point scalePoint(Point p, num Function(num v) convert) {
  return Point(convert(p.x), convert(p.y));
}

Point roundPoint(Point p) => scalePoint(p, (v) => v.round());

Point<T> clamp<T extends num>(Point<T> point, Point<T> pMin, Point<T> pMax,
    [num inset = 0]) {
  return Point<T>(min(max(point.x, pMin.x), pMax.x + inset),
      min(max(point.y, pMin.y), pMax.y + inset));
}

Point<T> clampMin<T extends num>(Point<T> point, Point<T> pMin) {
  return Point<T>(max(point.x, pMin.x), max(point.y, pMin.y));
}
