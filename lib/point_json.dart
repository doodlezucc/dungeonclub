import 'dart:math';

Point parsePoint(dynamic json) {
  return json == null ? null : Point(json['x'], json['y']);
}

Map<String, dynamic> writePoint(Point point) => {
      'x': point.x,
      'y': point.y,
    };
