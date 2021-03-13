import 'dart:html';
import 'dart:math';

import 'package:dnd_interactive/actions.dart';

import '../communication.dart';
import '../panels/upload.dart' as upload;
import 'grid.dart';
import 'movable.dart';
import 'session.dart';

final HtmlElement _container = querySelector('#boardContainer');
final HtmlElement _e = querySelector('#board');
final ImageElement _ground = _e.querySelector('#ground');

final HtmlElement _controls = _container.querySelector('.controls');
final ButtonElement _changeImage = _controls.querySelector('#changeImage');

class Board {
  final Session session;
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

  int _sceneId;
  bool _init = false;

  Board(this.session) {
    position = Point(0, 0);

    if (!_init) {
      _initBoard();
      _init = true;
    }
  }

  void _initBoard() {
    var drag = false;
    _container.onMouseDown.listen((event) async {
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

    _container.onMouseWheel.listen((event) {
      zoom -= event.deltaY / 300;
    });

    _changeImage.onClick.listen((event) async {
      var img = await upload.display(
        type: IMAGE_TYPE_SCENE,
        maxRes: 2048,
        extras: {
          'gameId': session.id,
          'id': _sceneId,
        },
      );

      if (img != null) {
        onImgChange(img);
      }
    });
  }

  void _transform() {
    _e.style.transform =
        'scale($_scaledZoom) translate(${position.x}px, ${position.y}px)';
  }

  void onImgChange([String src]) async {
    // ew
    src = src ??
        'http://localhost:7070/database/games/${session.id}/scene$_sceneId.png';
    _ground.src = '$src?${DateTime.now().millisecondsSinceEpoch}';
    await _ground.onLoad.first;
    grid.resize(_ground.naturalWidth, _ground.naturalHeight);
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

  void fromJson(int id, Map<String, dynamic> json) {
    _sceneId = id;
    onImgChange();
    for (var m in json['movables']) {
      onMovableCreate(m);
    }
  }
}
