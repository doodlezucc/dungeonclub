import 'dart:math';

import 'package:grid_space/grid_space.dart';

Point<T>? parsePoint<T extends num>(dynamic json) {
  if (json == null) return null;

  num x = json['x'];
  num y = json['y'];
  return Point(x.cast<T>(), y.cast<T>());
}

Map<String, dynamic> writePoint(Point point) => {
      'x': point.x.undeviateAny(),
      'y': point.y.undeviateAny(),
    };

Map<String, dynamic>? writePointOrNull(Point? point) => point != null
    ? {
        'x': point.x.undeviateAny(),
        'y': point.y.undeviateAny(),
      }
    : null;

Point<T> scalePoint<T extends num>(Point p, T Function(num v) convert) {
  return Point(convert(p.x), convert(p.y));
}

Point roundPoint(Point p) => scalePoint(p, (v) => v.round());

Point<T> clamp<T extends num>(Point<T> point, Point<T> pMin, Point<T> pMax,
    [num inset = 0]) {
  return Point<T>(min(max(point.x, pMin.x), (pMax.x + inset) as T),
      min(max(point.y, pMin.y), (pMax.y + inset) as T));
}

Point<T> clampMin<T extends num>(Point<T> point, Point<T> pMin) {
  return Point<T>(max(point.x, pMin.x), max(point.y, pMin.y));
}

extension DoubleExtension on num {
  double undeviate() {
    return (this * 100).roundToDouble() / 100;
  }

  num undeviateAny() {
    if (this is int) return this;
    return undeviate();
  }
}

extension PointNumExtension<T extends num> on Point<T> {
  Point<double> snapDeviation() {
    return Point(x.undeviate(), y.undeviate());
  }

  Point<T> snapDeviationAny() {
    return Point(x.undeviateAny() as T, y.undeviateAny() as T);
  }

  Point<int> ceil() {
    return Point(x.ceil(), y.ceil());
  }
}

extension PointDoubleExtension on Point<double> {
  Point<double> undeviate() {
    return Point<double>(x.undeviate(), y.undeviate());
  }
}
