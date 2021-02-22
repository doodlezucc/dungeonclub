import 'dart:html';
import 'dart:math';

import '../communication.dart';
import '../server_actions.dart';
import 'grid.dart';
import 'movable.dart';
import 'session.dart';

class Board {
  final Session session;
  final HtmlElement e = querySelector('#board');
  final HtmlElement container = querySelector('#boardContainer');
  final ImageElement ground = querySelector('#board #ground');
  final grid = Grid();
  final movables = <Movable>[];

  Point _position;
  Point get position => _position;
  set position(Point pos) {
    _position = pos;
    _transform();
  }

  double _zoom = 0;
  double _scaledZoom = 1;
  double get zoom => _zoom;
  double get scaledZoom => _scaledZoom;
  set zoom(double zoom) {
    _zoom = zoom;
    _scaledZoom = exp(zoom);
    _transform();
  }

  Board(this.session) {
    position = Point(0, 0);

    grid.resize(ground.width, ground.height);

    var drag = false;
    container.onMouseDown.listen((event) async {
      if ((event.target as HtmlElement).className.contains('movable')) return;
      drag = true;
      await window.onMouseUp.first;
      drag = false;
    });
    window.onMouseMove.listen((event) {
      if (drag) {
        position += event.movement * (1 / _scaledZoom);
      }
    });

    container.onMouseWheel.listen((event) {
      zoom -= event.deltaY / 300;
    });
  }

  void _transform() {
    e.style.transform =
        'scale($_scaledZoom) translate(${position.x}px, ${position.y}px)';
  }

  Future<Movable> addMovable(String img) async {
    var m = Movable(board: this, img: img);
    var id = await socket.request(GAME_MOVABLE_CREATE, {
      'x': m.position.x,
      'y': m.position.y,
      'img': img,
    });
    m.id = id;
    movables.add(m);
    grid.e.append(m.e);
    return m;
  }

  static Point parsePoint(dynamic json) {
    return Point(json['x'], json['y']);
  }

  void onMovableCreate(Map<String, dynamic> json) {
    var m = Movable(
      board: this,
      img: json['img'],
      id: json['id'],
      pos: parsePoint(json),
    );
    movables.add(m);
    grid.e.append(m.e);
  }

  void onMovableMove(json) {
    for (var m in movables) {
      if (m.id == json['id']) {
        return m.onMove(parsePoint(json));
      }
    }
  }

  void fromJson(Map<String, dynamic> json) {
    for (var m in json['movables']) {
      onMovableCreate(m);
    }
  }
}
