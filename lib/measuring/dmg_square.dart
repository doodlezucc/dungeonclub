import 'dart:math';
import 'package:grid/grid.dart';

import 'ruleset.dart';

class DMGSquareMeasuringRuleset extends SquareMeasuringRuleset {
  @override
  int distanceBetweenCells(SquareGrid grid, Point<int> a, Point<int> b) {
    return MeasuringRuleset.chebychov(a, b);
  }

  @override
  num distanceBetweenIntersections(
      SquareGrid grid, Point<double> a, Point<double> b) {
    return MeasuringRuleset.chebychov(a, b);
  }
}
