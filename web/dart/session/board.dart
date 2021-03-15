import 'dart:html';
import 'dart:math';

import 'package:dnd_interactive/actions.dart' as a;
import 'package:dnd_interactive/point_json.dart';

import '../communication.dart';
import '../panels/upload.dart' as upload;
import 'grid.dart';
import 'movable.dart';
import 'scene.dart';
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
  Scene refScene;
  bool _init = false;

  Board(this.session) {
    position = Point(0, 0);

    if (!_init) {
      _initBoard();
      _init = true;
    }
  }

  void _initBoard() {
    _initDragControls();

    _container.onMouseWheel.listen((event) {
      zoom -= event.deltaY / 300;
    });

    _changeImage.onClick.listen((_) => _changeImageDialog());
  }

  void _initDragControls() {
    var isBoardDrag = false;
    var drag = false;
    _container.onMouseDown.listen((event) async {
      var movable = (event.target as HtmlElement).classes.contains('movable');

      if (event.path.contains(_controls) || (!grid.editingGrid && movable)) {
        return;
      }

      isBoardDrag = event.path.contains(_e);
      drag = true;
      await window.onMouseUp.first;
      drag = false;
    });
    window.onMouseMove.listen((event) {
      if (drag) {
        var delta = event.movement * (1 / _scaledZoom);

        if (!grid.editingGrid || !isBoardDrag) {
          position += delta;
        } else {
          grid.offset += delta;
        }
      }
    });
  }

  Future<void> _changeImageDialog() async {
    var img = await upload.display(
      action: a.GAME_SCENE_UPDATE,
      type: a.IMAGE_TYPE_SCENE,
      extras: {
        'id': _sceneId,
      },
    );

    if (img != null) {
      onImgChange(src: img);
    }
  }

  void _transform() {
    _e.style.transform =
        'scale($_scaledZoom) translate(${position.x}px, ${position.y}px)';
  }

  void onImgChange({String src, bool updateRef = true}) async {
    src = src ?? Scene.getSceneImage(_sceneId);
    src += '?${DateTime.now().millisecondsSinceEpoch}';
    _ground.src = src;
    if (updateRef) {
      refScene?.image = src;
    }
    await _ground.onLoad.first;
    grid.resize(_ground.naturalWidth, _ground.naturalHeight);
  }

  void clear() {
    movables.forEach((m) => m.e.remove());
    movables.clear();
  }

  Future<Movable> addMovable(String img) async {
    var m = Movable(board: this, img: img);
    var id = await socket.request(a.GAME_MOVABLE_CREATE, {
      'x': m.position.x,
      'y': m.position.y,
      'img': img,
    });
    m.id = id;
    movables.add(m);
    grid.e.append(m.e);
    return m;
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
    clear();

    _sceneId = id;
    onImgChange(updateRef: false);

    grid.fromJson(json['grid']);

    for (var m in json['movables']) {
      onMovableCreate(m);
    }
  }
}
