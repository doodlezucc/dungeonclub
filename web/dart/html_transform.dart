import 'dart:html';
import 'dart:math';

import 'package:dnd_interactive/point_json.dart';

final _scaledMin = 1 / e;
final _scaledMax = exp(1.5);

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
  set zoom(double zoom) {
    _zoom = min(max(zoom, -1), 1.5);
    _scaledZoom = exp(_zoom);
    _transform();
  }

  double get scaledZoom => _scaledZoom;
  set scaledZoom(double scaled) {
    _scaledZoom = min(max(scaled, _scaledMin), _scaledMax);
    _zoom = log(_scaledZoom);
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

  Future<void> _animate(double duration, void Function(double t) frame) async {
    var fps = 50;
    var step = (fps / 1000) / duration;
    for (var t = 1.0; t > 0; t -= step) {
      frame(t);
      await Future.delayed(Duration(milliseconds: 1000 ~/ fps));
    }
  }

  void applyZoomForce(double velocity) {
    _animate(0.3, (t) => zoom += velocity * t);
  }

  void applyForce(Point velocity) {
    _animate(velocity.magnitude / 50, (t) => position += velocity * t);
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
  Point p;
  Point movement;
  bool shift;
  bool ctrl;
  bool alt;
  int button;

  SimpleEvent(
      this.p, this.movement, this.shift, this.ctrl, this.alt, this.button);

  SimpleEvent.fromJS(Event ev, this.p, this.movement)
      : shift = (ev as dynamic).shiftKey,
        ctrl = (ev as dynamic).ctrlKey,
        alt = (ev as dynamic).altKey,
        button = ev is MouseEvent ? ev.button : 0;
}
