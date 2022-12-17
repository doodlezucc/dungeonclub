import 'dart:math';

import 'package:grid/grid.dart';
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
        normalizedTile -= Point(0.5, 0.5 * heightRatio);
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
  static Set<Point<int>> getTilesOverlappingPolygon(
    TiledGrid grid,
    List<Point<double>> points, {
    int centerIndex,
  }) {
    final bbox = _pointsToBoundingBox(points);
    final boundsMin = bbox.topLeft.floor();
    final boundsMax = bbox.bottomRight.floor() + Point(1, 1);

    final tilePoints = grid.tileShape.points;
    final bboxTile = _pointsToBoundingBox(tilePoints);

    final result = <Point<int>>{};
    final centerPoint = centerIndex != null ? points[centerIndex] : null;

    for (var tile in getTilesInBounds(boundsMin, boundsMax)) {
      final tileCast = tile.cast<double>();
      final bboxShifted = Rectangle(
        bbox.left - tileCast.x,
        bbox.top - tileCast.y,
        bbox.width,
        bbox.height,
      );

      if (!bboxTile.intersects(bboxShifted)) continue;

      final pointsShifted = points.map((p) => p - tileCast).toList();
      var contained = false;

      for (var p in tilePoints) {
        if (pointInsidePolygonPoints(p, pointsShifted, allowEdges: false)) {
          result.add(tile);
          contained = true;
          break;
        }
      }

      if (!contained) {
        // "skip(1)": Don't check if the AoE origin lies inside this tile
        Iterable<Point<double>> pointsShiftedExcept = pointsShifted;

        if (centerIndex != null) {
          pointsShiftedExcept = pointsShifted
              .take(centerIndex)
              .followedBy(pointsShifted.skip(centerIndex + 1));
        }

        for (var p in pointsShiftedExcept) {
          if (pointInsidePolygonPoints(p, tilePoints, allowEdges: false)) {
            result.add(tile);
            break;
          }
        }
      }
    }

    // Additionally check centers of tiles around center point
    if (centerPoint != null) {
      final centerRounded = centerPoint.round();
      for (var tile in getTilesInBounds(
          centerRounded - Point(2, 2), centerRounded + Point(2, 2))) {
        final tileCenter = grid.tileCenterInGrid(tile);
        if (pointInsidePolygonPoints(tileCenter, points, allowEdges: false)) {
          result.add(tile);
        }
      }
    }

    return result;
  }

  num distanceBetweenGridPoints(T grid, Point a, Point b);
}

abstract class SquareMeasuringRuleset extends MeasuringRuleset<SquareGrid> {}

abstract class HexMeasuringRuleset extends MeasuringRuleset<HexagonalGrid> {}

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
