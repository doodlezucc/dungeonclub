import 'dart:math';

import 'package:dungeonclub/measuring/area_of_effect.dart';
import 'package:dungeonclub/measuring/ruleset.dart';
import 'package:dungeonclub/shape_painter/painter.dart';
import 'package:grid/grid.dart';

class UnclampedMeasuringRuleset extends MeasuringRuleset<UnclampedGrid>
    with
        SupportsSphere<UnclampedGrid>,
        SupportsCube<UnclampedGrid>,
        SupportsCone<UnclampedGrid>,
        SupportsLine<UnclampedGrid> {
  @override
  num distanceBetweenGridPoints(UnclampedGrid grid, Point a, Point b) {
    return a.cast<num>().distanceTo(b); // Standard euclidean distance
  }

  @override
  Set<Point<int>> getTilesAffectedBySphere(SphereAreaOfEffect aoe) => const {};

  @override
  Set<Point<int>> getTilesAffectedByCube(CubeAreaOfEffect aoe) => const {};

  @override
  CubeAreaOfEffect makeInstance() => SquareCubeAreaOfEffect(useDistance: false);

  @override
  Set<Point<int>> getTilesAffectedByPolygon(Polygon polygon, UnclampedGrid grid,
          {bool checkCenter = false}) =>
      const {};

  @override
  double snapTokenAngle(double degrees) => degrees; // No angle snapping
}
