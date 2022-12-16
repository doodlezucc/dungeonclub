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

  @override
  Rect rect() => SvgRect(transform);
}

extension SvgAttributeHelper on svg.SvgElement {
  operator []=(String name, dynamic value) {
    setAttribute(name, value);
  }

  void attrPx(String name, dynamic value) {
    setAttribute(name, '${value}px');
  }

  void attrPoint(String nameX, String nameY, Point point) {
    attrPx(nameX, point.x);
    attrPx(nameY, point.y);
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
  set radius(double r) {
    super.radius = r;
    element.attrPx('r', r * transform.sizing.x);
  }

  @override
  set center(Point<double> p) {
    super.center = p;
    final normalized = transform.translate(p);
    element.attrPoint('cx', 'cy', normalized);
  }
}

class SvgRect extends SvgShape<svg.RectElement> with Rect {
  SvgRect(PaintTransform transform)
      : super(
          transform,
          svg.RectElement()..classes.add('no-fill'),
        );

  @override
  set position(Point p) {
    super.position = p;
    final normalized = transform.translate(p);
    element.attrPoint('x', 'y', normalized);
  }

  @override
  set size(Point s) {
    super.position = s;
    final scale = transform.sizing;
    final normalized = Point(s.x * scale.x, s.y * scale.y);
    element.attrPoint('width', 'height', normalized);
  }
}
