import 'dart:math';

import 'package:dungeonclub/measuring/area_of_effect.dart';
import 'package:dungeonclub/measuring/ruleset.dart';
import 'package:grid/grid.dart';

class UnclampedMeasuringRuleset extends MeasuringRuleset<UnclampedGrid>
    with SupportsSphere<UnclampedGrid> {
  @override
  num distanceBetweenGridPoints(UnclampedGrid grid, Point a, Point b) {
    return a.distanceTo(b); // Standard euclidean distance
  }

  @override
  Set<Point<int>> getTilesAffectedBySphere(
      SphereAreaOfEffect<UnclampedGrid> aoe) {
    return const {};
  }
}
