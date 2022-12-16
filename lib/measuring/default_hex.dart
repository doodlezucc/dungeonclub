import 'dart:math';

import 'package:dungeonclub/measuring/area_of_effect.dart';
import 'package:dungeonclub/point_json.dart';
import 'package:grid/grid.dart';

import 'ruleset.dart';

class DefaultHexMeasuringRuleset extends HexMeasuringRuleset
    with SupportsSphere<HexagonalGrid>, SupportsCube<HexagonalGrid> {
  static const degrees30 = pi / 6;
  static const degrees60 = pi / 3;

  /// Determines the distance between two points on a hex grid.
  ///
  /// This is done by sorting the vector between `A` and `B` into one of six
  /// triangles. This triangle is then rotated around the origin to point
  /// upwards, which lets us look at a straight horizontal line that
  /// crosses `B`. The distance between `A` and `B` is the (normalized)
  /// Y coordinate of this line.
  @override
  num distanceBetweenGridPoints(HexagonalGrid grid, Point a, Point b) {
    final vx = b.x - a.x;
    final vy = (b.y - a.y) * grid.tileHeightRatio;

    double result;

    if (grid.horizontal) {
      final angle = (atan2(vx, -vy) + pi) ~/ degrees60;
      var rotate = -angle * degrees60 - degrees30;
      result = vx * sin(rotate) + vy * cos(rotate);
    } else {
      final angle = (atan2(vx, -vy) + pi * 7 / 6) ~/ degrees60;
      var rotate = -angle * degrees60;
      result = (vx * sin(rotate) + vy * cos(rotate)) / grid.tileHeightRatio;
    }

    return result.undeviate();
  }

  @deprecated
  int distanceBetweenCells(HexagonalGrid grid, Point<int> a, Point<int> b) {
    // Calculations are based on a vertical grid - apply conversion
    if (grid.horizontal) {
      a = Point(a.y, a.x);
      b = Point(b.y, b.x);
    }

    final deltaX = b.x - a.x;
    final deltaYAbs = (b.y - a.y).abs();

    var xDistance = -deltaYAbs / 2;
    if (deltaYAbs % 2 == 0) {
      xDistance += deltaX.abs();
    } else {
      final srcIsShifted = a.y % 2 == 1;
      var rangeOffset = srcIsShifted ? -0.5 : 0.5;
      xDistance += (deltaX + rangeOffset).abs();
    }

    final xSteps = xDistance.truncate();
    return deltaYAbs + max(0, xSteps);
  }

  @override
  Set<Point<int>> getTilesAffectedBySphere(
          SphereAreaOfEffect<HexagonalGrid> aoe) =>
      MeasuringRuleset.getTilesWithinCircle(aoe.grid, aoe.center, aoe.radius);

  @override
  Set<Point<int>> getTilesAffectedByCube(covariant HexCubeAreaOfEffect aoe) =>
      MeasuringRuleset.getTilesWithinCircle(aoe.grid, aoe.origin, aoe.distance,
          useTileShape: true);

  @override
  HexCubeAreaOfEffect makeInstance() => HexCubeAreaOfEffect();
}
