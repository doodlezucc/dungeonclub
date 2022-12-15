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
  Set<Point<int>> getTilesAffectedBySphere(
          SphereAreaOfEffect<SquareGrid> aoe) =>
      MeasuringRuleset.getTilesWithinCircle(aoe.grid, aoe.center, aoe.radius);
}
