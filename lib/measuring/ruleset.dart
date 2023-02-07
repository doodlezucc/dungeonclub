import 'dart:math';

import 'package:grid_space/grid_space.dart';
import 'package:web_polymask/math/polymath.dart';

import 'default_hex.dart';
import 'dmg_square.dart';
import 'unclamped.dart';

abstract class MeasuringRuleset<T extends Grid> {
  static final unclampedDefault = UnclampedMeasuringRuleset();
  static final squareDmg = DMGSquareMeasuringRuleset();
  static final hexDefault = DefaultHexMeasuringRuleset();

  static final squareRulesets = <SquareMeasuringRuleset>[
    squareDmg,
  ];
  static final hexRulesets = <HexMeasuringRuleset>[
    hexDefault,
  ];

  static final allRulesets = {
    unclampedDefault,
    ...squareRulesets,
    ...hexRulesets
  };

  /// Chebyshev distance. Returns either the horizontal or the vertical
  /// difference, whichever is greater.
  static U chebyshev<U extends num>(Point<U> a, Point<U> b) {
    return max((a.x - b.x).abs(), (a.y - b.y).abs());
  }

  /// Returns all tiles in bounds `from` (inclusive) - `to` (exclusive).
  static Set<Point<int>> getTilesInBounds(Point<int> from, Point<int> to) {
    final result = <Point<int>>{};

    final boundsMin = from.round();
    final boundsMax = to.round();

    for (var x = boundsMin.x; x < boundsMax.x; x++) {
      for (var y = boundsMin.y; y < boundsMax.y; y++) {
        result.add(Point(x, y));
      }
    }

    return result;
  }

  /// Returns all tiles which are centered within the radius of a circle.
  static Set<Point<int>> getTilesWithinCircle(
    TiledGrid grid,
    Point<double> center,
    double radius, {
    bool useTileShape = false,
  }) {
    final heightRatio = grid.tileHeightRatio;
    final radiusPointMax =
        Point(radius + 3, (radius + 3) / heightRatio).floor();

    center = Point(center.x, center.y * heightRatio);
    final centerFloored = center.floor();

    final boundsMin = centerFloored - radiusPointMax;
    final boundsMax = centerFloored + radiusPointMax + Point(1, 1);

    final result = <Point<int>>{};
    final thresholdSqr = pow(radius + 0.05, 2);

    for (var tile in getTilesInBounds(boundsMin, boundsMax)) {
      final tc = grid.tileCenterInGrid(tile);
      var normalizedTile = Point(tc.x, tc.y * heightRatio);

      if (!useTileShape) {
        if (normalizedTile.squaredDistanceTo(center) <= thresholdSqr) {
          result.add(tile);
        }
      } else {
        for (var point in grid.tileShape.points) {
          final sum = point + normalizedTile;
          if (sum.squaredDistanceTo(center) <= thresholdSqr) {
            result.add(tile);
            break;
          }
        }
      }
    }

    return result;
  }

  /// Returns all tiles which are intersecting or contained inside a polygon.
  ///
  /// If `checkCenter` is true, tile centers are included in the calculation
  /// (instead of only the outlining points of a tile).
  static Set<Point<int>> getTilesOverlappingPolygon(
    TiledGrid grid,
    List<Point<double>> points, {
    bool checkCenter = false,
  }) {
    final bbox = _pointsToBoundingBox(points);
    final boundsMin = bbox.topLeft.floor() - Point(1, 1);
    final boundsMax = bbox.bottomRight.floor() + Point(2, 2);

    final tilePoints = grid.tileShape.points;
    final bboxTile = _pointsToBoundingBox(tilePoints);

    final result = <Point<int>>{};

    for (var tile in getTilesInBounds(boundsMin, boundsMax)) {
      final tileCenter = grid.tileCenterInGrid(tile);
      final bboxShifted = Rectangle(
        bbox.left - tileCenter.x,
        bbox.top - tileCenter.y,
        bbox.width,
        bbox.height,
      );

      if (!bboxTile.intersects(bboxShifted)) continue;

      final pointsShifted = points.map((p) => p - tileCenter).toList();
      var contained = false;

      // Check for tile points inside the polygon
      for (var p in tilePoints) {
        if (pointInsidePolygonPoints(p, pointsShifted, allowEdges: false)) {
          result.add(tile);
          contained = true;
          break;
        }
      }

      if (contained) continue;

      if (checkCenter) {
        final centerInPolygon = pointInsidePolygonPoints(
          const Point(0, 0),
          pointsShifted,
          allowEdges: false,
        );

        if (centerInPolygon) {
          result.add(tile);
          continue;
        }
      }

      // Check for polygon points inside the tile
      for (var p in pointsShifted) {
        if (pointInsidePolygonPoints(p, tilePoints, allowEdges: false)) {
          result.add(tile);
          break;
        }
      }
    }

    return result;
  }

  /// Returns all tiles which are intersecting a line from `a` to `b`.
  static Set<Point<int>> getTilesOverlappingLine(
    TiledGrid grid,
    Point<double> a,
    Point<double> b,
  ) {
    final bbox = _pointsToBoundingBox([a, b]);
    final boundsMin = bbox.topLeft.floor() - Point(1, 1);
    final boundsMax = bbox.bottomRight.floor() + Point(2, 2);

    final tilePoints = grid.tileShape.points;
    final result = <Point<int>>{};

    for (var tile in getTilesInBounds(boundsMin, boundsMax)) {
      final tileCenter = grid.tileCenterInGrid(tile);

      final u = a - tileCenter;
      final v = b - tileCenter;
      if (_polygonIntersectsLine(tilePoints, u, v)) {
        result.add(tile);
      }
    }

    return result;
  }

  num distanceBetweenGridPoints(T grid, Point a, Point b);
  double snapTokenAngle(double degrees);
}

abstract class SquareMeasuringRuleset extends MeasuringRuleset<SquareGrid> {
  @override
  double snapTokenAngle(double degrees) => _snapNumber(degrees, 45);
}

abstract class HexMeasuringRuleset extends MeasuringRuleset<HexagonalGrid> {
  @override
  double snapTokenAngle(double degrees) => _snapNumber(degrees, 30);
}

/// Rounds `v` to the closest step so that `v % step == 0`.
double _snapNumber(double v, double step) {
  return (v / step).roundToDouble() * step;
}

Rectangle _pointsToBoundingBox(List<Point> points) {
  var p1 = points.first;
  var xMin = p1.x;
  var xMax = p1.x;
  var yMin = p1.y;
  var yMax = p1.y;

  for (var i = 1; i < points.length; i++) {
    var p = points[i];
    if (p.x < xMin) {
      xMin = p.x;
    } else if (p.x > xMax) {
      xMax = p.x;
    }

    if (p.y < yMin) {
      yMin = p.y;
    } else if (p.y > yMax) {
      yMax = p.y;
    }
  }

  return Rectangle(xMin, yMin, xMax - xMin, yMax - yMin);
}

bool _polygonIntersectsLine(List<Point> points, Point a, Point b) {
  var u = points.last;
  for (var i = 0; i < points.length; i++) {
    var v = points[i];

    if (segmentIntersect(a, b, u, v) != null) return true;

    u = v;
  }

  return false;
}
