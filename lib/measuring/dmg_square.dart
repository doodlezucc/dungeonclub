import 'dart:math';
import 'package:dungeonclub/measuring/area_of_effect.dart';
import 'package:grid/grid.dart';

import 'ruleset.dart';

class DMGSquareMeasuringRuleset extends SquareMeasuringRuleset
    with SupportsSphere<SquareGrid>, SupportsCube<SquareGrid> {
  @override
  num distanceBetweenGridPoints(Grid grid, Point a, Point b) {
    return MeasuringRuleset.chebyshev(a, b);
  }

  @override
  Set<Point<int>> getTilesAffectedBySphere(
          SphereAreaOfEffect<SquareGrid> aoe) =>
      MeasuringRuleset.getTilesWithinCircle(aoe.grid, aoe.center, aoe.radius);

  @override
  Set<Point<int>> getTilesAffectedByCube(covariant SquareCubeAreaOfEffect aoe) {
    final result = <Point<int>>{};

    final boundsMin = aoe.boundsMin.round();
    final boundsMax = aoe.boundsMax.round();

    for (var x = boundsMin.x; x < boundsMax.x; x++) {
      for (var y = boundsMin.y; y < boundsMax.y; y++) {
        result.add(Point(x, y));
      }
    }

    return result;
  }

  @override
  SquareCubeAreaOfEffect makeInstance() =>
      SquareCubeAreaOfEffect(useDistance: true);
}
