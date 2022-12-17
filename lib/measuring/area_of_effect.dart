import 'dart:math';

import 'package:dungeonclub/measuring/ruleset.dart';
import 'package:grid/grid.dart';
import 'package:meta/meta.dart';

import '../shape_painter/painter.dart';

abstract class AreaOfEffectTemplate<S extends _Supports> {
  S _ruleset;
  S get ruleset => _ruleset;

  Grid _grid;
  Grid get grid => _grid;

  double get distanceMultiplier => 1;

  ShapeGroup _group;

  void create(
    Point<double> origin,
    ShapePainter painter,
    S ruleset,
    Grid grid,
  ) {
    _ruleset = ruleset;
    _grid = grid;
    _group = ShapeGroup(painter);
    initialize(origin, _group);

    for (var shape in _group.shapes) {
      painter.addShape(shape);
    }
  }

  void dispose(ShapePainter painter) {
    for (var shape in _group.shapes) {
      painter.removeShape(shape);
    }
  }

  Set<Point<int>> getAffectedTiles();

  @protected
  void initialize(Point<double> origin, ShapeMaker maker);
  bool onMove(Point<double> position, double distance);
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
  bool onMove(Point<double> position, double distance) {
    if (_outline.radius == distance) return false;

    _outline.radius = distance;
    return true;
  }

  @override
  Set<Point<int>> getAffectedTiles() => ruleset.getTilesAffectedBySphere(this);
}

abstract class CubeAreaOfEffect<G extends Grid>
    extends AreaOfEffectTemplate<SupportsCube<G>> {
  @override
  G get grid => _grid;

  @override
  Set<Point<int>> getAffectedTiles() => ruleset.getTilesAffectedByCube(this);
}

class SquareCubeAreaOfEffect extends CubeAreaOfEffect {
  final bool useDistance;
  Rect _rect;

  Point<double> _from;
  Point<double> _to;

  Point<double> get boundsMin =>
      Point(min(_from.x, _to.x), min(_from.y, _to.y));
  Point<double> get boundsMax =>
      Point(max(_from.x, _to.x), max(_from.y, _to.y));

  SquareCubeAreaOfEffect({@required this.useDistance});

  void _updateRect() {
    final bMin = boundsMin;
    _rect
      ..position = bMin
      ..size = boundsMax - bMin;
  }

  @override
  void initialize(Point<double> origin, ShapeMaker maker) {
    _rect = maker.rect();
    _from = _to = origin;
    _updateRect();
  }

  @override
  bool onMove(Point<double> position, double distance) {
    final v = position - _from;
    final size = useDistance ? distance : max(v.x.abs(), v.y.abs());

    final to = _from + Point(v.x.sign * size, v.y.sign * size);

    if (to == _to) return false;

    _to = to;
    _updateRect();
    return true;
  }
}

class HexCubeAreaOfEffect extends CubeAreaOfEffect<HexagonalGrid> {
  Rect _rect;

  Point<double> _origin;
  Point<double> get origin => _origin;

  double _distance;
  double get distance => _distance;

  @override
  double get distanceMultiplier => 0.5;

  @override
  void initialize(Point<double> origin, ShapeMaker maker) {
    _origin = origin;
    _rect = maker.rect();
  }

  @override
  bool onMove(Point<double> position, double distance) {
    distance = max(0, distance - 0.5);
    if (distance == _distance) return false;

    _distance = distance;

    final distTwice = distance * 2;
    _rect.position = origin - Point(distance, distance);
    _rect.size = Point(distTwice, distTwice);
    return true;
  }
}

class ConeAreaOfEffect<G extends Grid>
    extends AreaOfEffectTemplate<SupportsCone<G>> {
  Polygon _polygon;

  Point<double> _origin;
  Point<double> get origin => _origin;

  double _distance;
  double get distance => _distance;

  @override
  void initialize(Point<double> origin, ShapeMaker maker) {
    _origin = origin;
    _polygon = maker.polygon()..points = [origin, origin, origin];
  }

  @override
  bool onMove(Point<double> position, double distance) {
    if (distance == 0) {
      if (_distance != 0) {
        _distance = 0;
        _polygon.points[1] = _polygon.points[2] = origin;
        _polygon.handlePointsChanged();
        return true;
      } else {
        return false;
      }
    }

    _distance = distance;

    final u = position - origin;
    final v = u * (distance / u.distanceTo(Point(0, 0)));

    final p1 = origin + v + Point<double>(-v.y / 2, v.x / 2);
    final p2 = origin + v + Point<double>(v.y / 2, -v.x / 2);

    _polygon.points[1] = p1;
    _polygon.points[2] = p2;
    _polygon.handlePointsChanged();
    return true;
  }

  @override
  Set<Point<int>> getAffectedTiles() {
    if (distance == 0) return const {};
    return ruleset.getTilesAffectedByCone(_polygon, grid);
  }
}

mixin _Supports<G extends Grid> on MeasuringRuleset<G> {}

mixin SupportsSphere<G extends Grid> implements _Supports<G> {
  SphereAreaOfEffect<G> aoeSphere(
    Point<double> origin,
    ShapePainter painter,
    G grid,
  ) =>
      SphereAreaOfEffect()..create(origin, painter, this, grid);

  Set<Point<int>> getTilesAffectedBySphere(SphereAreaOfEffect<G> aoe);
}

mixin SupportsCube<G extends Grid> implements _Supports<G> {
  CubeAreaOfEffect aoeCube(
    Point<double> origin,
    ShapePainter painter,
    G grid,
  ) =>
      makeInstance()..create(origin, painter, this, grid);

  CubeAreaOfEffect makeInstance();
  Set<Point<int>> getTilesAffectedByCube(CubeAreaOfEffect aoe);
}

mixin SupportsPolygon<G extends Grid> implements _Supports<G> {
  Set<Point<int>> getTilesAffectedByPolygon(Polygon polygon, G grid);
}

mixin SupportsCone<G extends Grid> implements SupportsPolygon<G> {
  ConeAreaOfEffect aoeCone(
    Point<double> origin,
    ShapePainter painter,
    G grid,
  ) =>
      ConeAreaOfEffect()..create(origin, painter, this, grid);

  Set<Point<int>> getTilesAffectedByCone(Polygon polygon, G grid) =>
      getTilesAffectedByPolygon(polygon, grid);
}
