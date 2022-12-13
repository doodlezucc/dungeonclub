import 'dart:math';

import 'package:dungeonclub/measuring/ruleset.dart';
import 'package:grid/grid.dart';
import 'package:meta/meta.dart';

abstract class AreaOfEffectPainter with ShapeMaker {
  void addShape(Shape shape);
  void removeShape(Shape shape);
}

mixin ShapeMaker {
  Circle circle();
}

class ShapeGroup with ShapeMaker {
  final ShapeMaker _maker;
  final shapes = <Shape>[];

  ShapeGroup(ShapeMaker maker) : _maker = maker;

  Shape _wrap(Shape shape) {
    shapes.add(shape);
    return shape;
  }

  @override
  Circle circle() => _wrap(_maker.circle());
}

abstract class AreaOfEffectTemplate<S extends _Supports> {
  S _ruleset;
  S get ruleset => _ruleset;

  Grid _grid;
  Grid get grid => _grid;

  ShapeGroup _group;

  void create(
    Point<double> origin,
    AreaOfEffectPainter painter,
    S ruleset,
    Grid grid,
  ) {
    _ruleset = ruleset;
    _grid = grid;
    _group = ShapeGroup(painter);
    initialize(origin, _group);
    onMove(origin);

    for (var shape in _group.shapes) {
      painter.addShape(shape);
    }
  }

  void dispose(AreaOfEffectPainter painter) {
    for (var shape in _group.shapes) {
      painter.removeShape(shape);
    }
  }

  Set<Point<int>> getAffectedTiles();

  @protected
  void initialize(Point<double> origin, ShapeMaker maker);
  void onMove(Point<double> position);
}

class SphereAreaOfEffect<G extends Grid>
    extends AreaOfEffectTemplate<SupportsSphere<G>> {
  @override
  G get grid => _grid;
  Circle _outline;

  Point<double> get center => _outline.center;
  double get radius => _outline.radius;

  @override
  void initialize(Point<double> origin, ShapeMaker maker) {
    _outline = maker.circle()..center = origin;
  }

  @override
  void onMove(Point<double> position) {
    _outline.radius =
        ruleset.distanceBetweenGridPoints(grid, _outline.center, position);
  }

  @override
  Set<Point<int>> getAffectedTiles() {
    return ruleset.getTilesAffectedBySphere(this);
  }
}

mixin _Supports<G extends Grid> on MeasuringRuleset<G> {}

mixin SupportsSphere<G extends Grid> implements _Supports<G> {
  SphereAreaOfEffect<G> aoeSphere(
    Point<double> origin,
    AreaOfEffectPainter painter,
    G grid,
  ) {
    return SphereAreaOfEffect()..create(origin, painter, this, grid);
  }

  Set<Point<int>> getTilesAffectedBySphere(SphereAreaOfEffect<G> aoe);
}

mixin Shape {}

mixin Circle implements Shape {
  Point<double> center;
  double radius;
}
