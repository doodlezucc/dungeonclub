import 'dart:math';

import 'package:grid/grid.dart';

import 'default_hex.dart';
import 'dmg_square.dart';
import 'unclamped.dart';

abstract class MeasuringRuleset<T extends Grid> {
  num distanceBetweenGridPoints(T grid, Point a, Point b);

  static final unclampedDefault = UnclampedMeasuringRuleset();
  static final squareDmg = DMGSquareMeasuringRuleset();
  static final hexDefault = DefaultHexMeasuringRuleset();

  static final squareRulesets = <SquareMeasuringRuleset>[
    squareDmg,
  ];
  static final hexRulesets = <HexMeasuringRuleset>[
    hexDefault,
  ];

  static final allRulesets = {
    unclampedDefault,
    ...squareRulesets,
    ...hexRulesets
  };

  /// Chebychov distance
  static U chebychov<U extends num>(Point<U> a, Point<U> b) {
    return max((a.x - b.x).abs(), (a.y - b.y).abs());
  }
}

abstract class SquareMeasuringRuleset extends MeasuringRuleset<SquareGrid> {}

abstract class HexMeasuringRuleset extends MeasuringRuleset<HexagonalGrid> {}
