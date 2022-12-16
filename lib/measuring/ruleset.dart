import 'dart:math';

import 'package:grid/grid.dart';

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
    final boundsMax = centerFloored + radiusPointMax;

    final result = <Point<int>>{};
    final thresholdSqr = pow(radius + 0.05, 2);

    for (var x = boundsMin.x; x <= boundsMax.x; x++) {
      for (var y = boundsMin.y; y <= boundsMax.y; y++) {
        final tile = Point(x, y);
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
    }

    return result;
  }

  num distanceBetweenGridPoints(T grid, Point a, Point b);
}

abstract class SquareMeasuringRuleset extends MeasuringRuleset<SquareGrid> {}

abstract class HexMeasuringRuleset extends MeasuringRuleset<HexagonalGrid> {}
