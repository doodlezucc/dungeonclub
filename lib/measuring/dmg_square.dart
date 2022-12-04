import 'dart:math';
import 'package:grid/grid.dart';

import 'ruleset.dart';

class DMGSquareMeasuringRuleset extends SquareMeasuringRuleset {
  @override
  num distanceBetweenGridPoints(SquareGrid grid, Point a, Point b) {
    return MeasuringRuleset.chebyshev(a, b);
  }
}
