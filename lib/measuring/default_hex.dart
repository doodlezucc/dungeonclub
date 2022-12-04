import 'dart:math';

import 'package:grid/grid.dart';

import 'ruleset.dart';

class DefaultHexMeasuringRuleset extends HexMeasuringRuleset {
  static const degrees30 = pi / 6;
  static const degrees60 = pi / 3;

  @override
  num distanceBetweenGridPoints(HexagonalGrid grid, Point a, Point b) {
    final vx = b.x - a.x;
    final vy = (b.y - a.y) * grid.tileHeight;
    if (grid.horizontal) {
      final angle = (atan2(vx, -vy) + pi) ~/ degrees60;
      var rotate = -angle * degrees60 - degrees30;
      return vx * sin(rotate) + vy * cos(rotate);
    } else {
      final angle = (atan2(vx, -vy) + pi * 7 / 6) ~/ degrees60;
      var rotate = -angle * degrees60;
      return (vx * sin(rotate) + vy * cos(rotate)) / grid.tileHeight;
    }
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
}
