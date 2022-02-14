import 'dart:html';
import 'dart:math';

import 'package:dnd_interactive/point_json.dart';
import 'package:meta/meta.dart';

class HtmlTransform {
  Element element;
  Point Function() getMaxPosition;

  Point _position;
  Point get position => _position;
  set position(Point pos) {
    var max = getMaxPosition() * 0.5;
    var min = Point(-max.x, -max.y);

    _position = clamp(pos, min, max);
    _transform();
  }

  double _zoom = 0;
  double _scaledZoom = 1;
  double get zoom => _zoom;
  double get scaledZoom => _scaledZoom;
  set zoom(double zoom) {
    _zoom = min(max(zoom, -1), 1.5);
    _scaledZoom = exp(_zoom);

    var invZoomScale = 'scale(${1 / scaledZoom})';
    querySelectorAll('.distance-text').style.transform = invZoomScale;

    _transform();
  }

  HtmlTransform(this.element, {@required this.getMaxPosition});

  void _transform() {
    element?.style?.transform =
        'scale($scaledZoom) translate(${position.x}px, ${position.y}px)';
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
}

class SimpleEvent {
  final Point p;
  final Point movement;
  final bool shift;
  final bool ctrl;
  final int button;

  SimpleEvent(this.p, this.movement, this.shift, this.ctrl, this.button);
}
