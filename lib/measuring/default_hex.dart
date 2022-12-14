import 'dart:math';

import 'package:dungeonclub/measuring/area_of_effect.dart';
import 'package:dungeonclub/point_json.dart';
import 'package:grid/grid.dart';

import 'ruleset.dart';

class DefaultHexMeasuringRuleset extends HexMeasuringRuleset
    with SupportsSphere<HexagonalGrid> {
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

  Point<double> _applyRatio(Point<double> point, HexagonalGrid grid) {
    return Point(point.x, point.y * grid.tileHeightRatio);
  }

  @override
  Set<Point<int>> getTilesAffectedBySphere(
      SphereAreaOfEffect<HexagonalGrid> aoe) {
    final grid = aoe.grid;
    final radius = aoe.radius;
    final center = _applyRatio(aoe.center, grid);
    final heightRatio = grid.tileHeightRatio;

    final radiusPointMax = Point(radius + 2, radius + 2).floor();
    final centerFloored = aoe.center.floor();

    var boundsMin = centerFloored - radiusPointMax;
    var boundsMax = centerFloored + radiusPointMax;
    boundsMin = Point(boundsMin.x, (boundsMin.y * heightRatio).floor());
    boundsMax = Point(boundsMax.x, (boundsMax.y * heightRatio).ceil());

    final result = <Point<int>>{};

    final radiusSqr = radius * radius;
    for (var x = boundsMin.x; x < boundsMax.x; x++) {
      for (var y = boundsMin.y; y < boundsMax.y; y++) {
        final tile = Point(x, y);
        final tileCenter = _applyRatio(grid.tileCenterInGrid(tile), grid);

        if (tileCenter.squaredDistanceTo(center) <= radiusSqr) {
          result.add(tile);
        }
      }
    }

    return result;
  }
}
