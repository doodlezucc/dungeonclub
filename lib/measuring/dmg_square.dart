import 'dart:math';
import 'package:dungeonclub/measuring/area_of_effect.dart';
import 'package:grid/grid.dart';

import 'ruleset.dart';

class DMGSquareMeasuringRuleset extends SquareMeasuringRuleset
    with SupportsSphere<SquareGrid> {
  @override
  num distanceBetweenGridPoints(Grid grid, Point a, Point b) {
    return MeasuringRuleset.chebyshev(a, b);
  }

  @override
  Set<Point<int>> getTilesAffectedBySphere(SphereAreaOfEffect<SquareGrid> aoe) {
    final radiusPointMax = Point(aoe.radius + 1, aoe.radius + 1).floor();
    final centerFloored = aoe.center.floor();

    final boundsMin = centerFloored - radiusPointMax;
    final boundsMax = centerFloored + radiusPointMax;

    final result = <Point<int>>{};

    final radiusSqr = aoe.radius * aoe.radius;
    for (var x = boundsMin.x; x < boundsMax.x; x++) {
      for (var y = boundsMin.y; y < boundsMax.y; y++) {
        final tile = Point(x, y);
        final tileCenter = aoe.grid.tileCenterInGrid(tile);
        if (tileCenter.squaredDistanceTo(aoe.center) <= radiusSqr) {
          result.add(tile);
        }
      }
    }

    return result;
  }
}
