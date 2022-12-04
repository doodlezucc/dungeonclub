import 'dart:math';

import 'package:dungeonclub/measuring/ruleset.dart';
import 'package:grid/grid.dart';

class UnclampedMeasuringRuleset extends MeasuringRuleset<UnclampedGrid> {
  @override
  num distanceBetweenGridPoints(UnclampedGrid grid, Point a, Point b) {
    return a.distanceTo(b); // Standard euclidean distance
  }
}
