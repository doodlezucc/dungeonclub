import 'dart:math';

import 'package:grid/grid.dart';

import 'ruleset.dart';

class DefaultHexMeasuringRuleset extends HexMeasuringRuleset {
  @override
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
  num distanceBetweenIntersections(
      HexagonalGrid grid, Point<double> a, Point<double> b) {
    throw UnimplementedError();
  }
}
