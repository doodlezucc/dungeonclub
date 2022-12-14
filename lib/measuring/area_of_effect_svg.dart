import 'dart:math';
import 'dart:svg' as svg;

import 'package:dungeonclub/measuring/area_of_effect.dart';

class PaintTransform {
  final Point<double> offset;
  final Point<double> sizing;

  PaintTransform(this.offset, this.sizing);

  Point<double> translate(Point p) {
    return Point<double>(
      offset.x + p.x * sizing.x,
      offset.y + p.y * sizing.y,
    );
  }
}

class AreaOfEffectSvgPainter extends AreaOfEffectPainter {
  final svg.GElement rootElement;
  final PaintTransform transform;

  AreaOfEffectSvgPainter(this.rootElement, this.transform);

  @override
  void addShape(covariant SvgShape e) {
    rootElement.append(e.element);
  }

  @override
  void removeShape(covariant SvgShape e) {
    rootElement.append(e.element);
  }

  @override
  Circle circle() => SvgCircle(transform);
}

extension SvgAttributeHelper on svg.SvgElement {
  operator []=(String name, dynamic value) {
    setAttribute(name, value);
  }

  void attrPx(String name, dynamic value) {
    setAttribute(name, '${value}px');
  }
}

abstract class SvgShape<E extends svg.SvgElement> with Shape {
  final PaintTransform transform;
  final E element;

  SvgShape(this.transform, this.element);
}

class SvgCircle extends SvgShape<svg.CircleElement> with Circle {
  SvgCircle(PaintTransform transform)
      : super(
          transform,
          svg.CircleElement()..classes.add('no-fill'),
        );

  @override
  set radius(double _radius) {
    super.radius = _radius;
    element.attrPx('r', radius * transform.sizing.x);
  }

  @override
  set center(Point<double> p) {
    super.center = p;
    final normalized = transform.translate(p);
    element.attrPx('cx', normalized.x);
    element.attrPx('cy', normalized.y);
  }
}
