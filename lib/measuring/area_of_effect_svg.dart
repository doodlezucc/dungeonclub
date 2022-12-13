import 'dart:math';
import 'dart:svg' as svg;

import 'package:dungeonclub/measuring/area_of_effect.dart';

class AreaOfEffectSvgPainter extends AreaOfEffectPainter {
  final svg.GElement rootElement;

  AreaOfEffectSvgPainter(this.rootElement);

  @override
  void addShape(covariant SvgShape e) {
    rootElement.append(e.element);
  }

  @override
  void removeShape(covariant SvgShape e) {
    rootElement.append(e.element);
  }

  @override
  Circle circle() => SvgCircle();
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
  final E element;

  SvgShape(this.element);
}

class SvgCircle extends SvgShape<svg.CircleElement> with Circle {
  SvgCircle() : super(svg.CircleElement()..classes.add('no-fill'));

  @override
  set radius(double _radius) {
    super.radius = _radius;
    element.attrPx('r', radius);
  }

  @override
  set center(Point<double> p) {
    super.center = p;
    element.attrPx('cx', p.x);
    element.attrPx('cy', p.y);
  }
}
