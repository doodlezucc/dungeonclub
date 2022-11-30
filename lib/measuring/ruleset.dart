import 'dart:math';

import 'package:grid/grid.dart';

import 'default_hex.dart';
import 'dmg_square.dart';

abstract class MeasuringRuleset<T extends Grid> {
  num distanceBetweenCells(T grid, Point<int> a, Point<int> b);
  num distanceBetweenIntersections(T grid, Point<double> a, Point<double> b);

  static final squareDmg = DMGSquareMeasuringRuleset();
  static final hexDefault = DefaultHexMeasuringRuleset();

  static final squareRulesets = <SquareMeasuringRuleset>[
    squareDmg,
  ];
  static final hexRulesets = <HexMeasuringRuleset>[
    hexDefault,
  ];

  static final allRulesets = {...squareRulesets, ...hexRulesets};

  /// Chebychov distance
  static U chebychov<U extends num>(Point<U> a, Point<U> b) {
    return max((a.x - b.x).abs(), (a.y - b.y).abs());
  }
}

abstract class SquareMeasuringRuleset extends MeasuringRuleset<SquareGrid> {}

abstract class HexMeasuringRuleset extends MeasuringRuleset<HexagonalGrid> {}
