import 'dart:math';
import 'package:dungeonclub/measuring/area_of_effect.dart';
import 'package:dungeonclub/shape_painter/painter.dart';
import 'package:grid/grid.dart';

import 'ruleset.dart';

class DMGSquareMeasuringRuleset extends SquareMeasuringRuleset
    with
        SupportsSphere<SquareGrid>,
        SupportsCube<SquareGrid>,
        SupportsCone<SquareGrid>,
        SupportsLine<SquareGrid> {
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
    return MeasuringRuleset.getTilesInBounds(
      aoe.boundsMin.round(),
      aoe.boundsMax.round(),
    );
  }

  @override
  SquareCubeAreaOfEffect makeInstance() =>
      SquareCubeAreaOfEffect(useDistance: true);

  @override
  Set<Point<int>> getTilesAffectedByPolygon(Polygon polygon, SquareGrid grid,
          {bool checkCenter = false}) =>
      MeasuringRuleset.getTilesOverlappingPolygon(grid, polygon.points,
          checkCenter: checkCenter);
}
