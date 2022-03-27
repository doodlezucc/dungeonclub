import 'dart:html';
import 'dart:math';

import 'package:dnd_interactive/point_json.dart';

class HtmlTransform {
  Element element;
  Point Function() getMaxPosition;

  HtmlTransform(this.element, {this.getMaxPosition});

  Point _position;
  Point get position => _position;
  set position(Point pos) {
    clampPosition(pos);
  }

  double _zoom = 0;
  double _scaledZoom = 1;
  double get zoom => _zoom;
  double get scaledZoom => _scaledZoom;
  set zoom(double zoom) {
    _zoom = min(max(zoom, -1), 1.5);
    _scaledZoom = exp(_zoom);
    _transform();
  }

  void _transform() {
    element?.style?.transform =
        'scale($scaledZoom) translate(${position.x}px, ${position.y}px)';
  }

  void clampPosition([Point pos]) {
    pos ??= position;

    var max = getMaxPosition() * 0.5;
    var min = Point(-max.x, -max.y);

    _position = clamp(pos, min, max);
    _transform();
  }

  void reset() {
    position = Point(0.0, 0.0);
    zoom = 0;
  }

  void handlePanning(SimpleEvent first, Stream<SimpleEvent> moveStream) {
    moveStream.listen((ev) {
      position += ev.movement * (1 / scaledZoom);
    });
  }

  void handleFineZooming(SimpleEvent first, Stream<SimpleEvent> moveStream) {
    moveStream.listen((ev) {
      zoom -= 0.01 * ev.movement.y;
    });
  }

  void handleMousewheel(WheelEvent event) {
    var v = min(50, event.deltaY.abs()) / 50;
    zoom -= event.deltaY.sign * v / 3;
  }
}

class SimpleEvent {
  final Point p;
  final Point movement;
  final bool shift;
  final bool ctrl;
  final bool alt;
  final int button;

  SimpleEvent(
      this.p, this.movement, this.shift, this.ctrl, this.alt, this.button);

  SimpleEvent.fromJS(Event ev, this.p, this.movement)
      : shift = (ev as dynamic).shiftKey,
        ctrl = (ev as dynamic).ctrlKey,
        alt = (ev as dynamic).altKey,
        button = ev is MouseEvent ? ev.button : 0;
}
