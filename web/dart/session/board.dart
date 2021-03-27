import 'dart:html';
import 'dart:math';

import 'package:dnd_interactive/actions.dart' as a;
import 'package:dnd_interactive/point_json.dart';
import 'package:meta/meta.dart';

import '../communication.dart';
import '../panels/upload.dart' as upload;
import 'grid.dart';
import 'movable.dart';
import 'prefab.dart';
import 'prefab_palette.dart';
import 'roll_dice.dart';
import 'scene.dart';
import 'session.dart';

final HtmlElement _container = querySelector('#boardContainer');
final HtmlElement _e = querySelector('#board');
final ImageElement _ground = _e.querySelector('#ground');

final HtmlElement _controls = _container.querySelector('#sceneEditor');
final ButtonElement _changeImage = _controls.querySelector('#changeImage');

final HtmlElement _selectionProperties = querySelector('#selectionProperties');
final InputElement _selectedSize = querySelector('#movableSize');

class Board {
  final Session session;
  final grid = Grid();
  final movables = <Movable>[];

  Movable _selectedMovable;
  Movable get selectedMovable => _selectedMovable;
  set selectedMovable(Movable selectedMovable) {
    if (_selectedMovable == selectedMovable) return;

    _selectedMovable?.e?.classes?.remove('selected');

    if (selectedMovable != null && !selectedMovable.accessible) {
      selectedMovable = null;
    }
    _selectedMovable = selectedMovable;

    if (selectedMovable != null) {
      selectedMovable.e.classes.add('selected');

      _selectedSize.valueAsNumber = selectedMovable.size;
      selectedMovable.e.append(_selectionProperties);
    } else {
      _selectionProperties.remove();
    }
  }

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
    initDiceTable();

    _container.onMouseWheel.listen((event) {
      zoom -= event.deltaY / 300;
    });

    _changeImage.onClick.listen((_) => _changeImageDialog());

    _container.onClick.listen((event) async {
      if (!event.path.contains(_e)) return;

      if (selectedPrefab != null) {
        var gridPos = _evToGridSpace(event, selectedPrefab);
        await addMovable(selectedPrefab, pos: gridPos);
        selectedPrefab = null;
      }
    });

    window.onKeyDown.listen((ev) {
      if (ev.keyCode == 27 && selectedPrefab != null) {
        ev.preventDefault();
        selectedPrefab = null;
      }
    });

    _listenSelectedLazyUpdate(_selectedSize, onChange: (input) {
      selectedMovable.size = input.valueAsNumber;
    });
    _selectionProperties.remove();
  }

  void _listenSelectedLazyUpdate(
    InputElement input, {
    @required void Function(InputElement self) onChange,
  }) {
    var bufferedValue = input.value;

    void update() async {
      if (bufferedValue != input.value) {
        bufferedValue = input.value;
        onChange(input);
        await socket.sendAction(a.GAME_MOVABLE_UPDATE, {
          'movable': selectedMovable.id,
          'size': selectedMovable.size,
        });
      }
    }

    input.onFocus.listen((_) {
      bufferedValue = input.value;
    });
    input.onChange.listen((_) => update());
  }

  void _initDragControls() {
    var isBoardDrag = false;
    var drag = false;
    _container.onMouseDown.listen((event) async {
      var movable = event.path
          .any((e) => e is HtmlElement && e.classes.contains('movable'));

      if (event.button == 0) {
        if (movable) {
          for (var mv in movables) {
            if (mv.e == event.target) {
              selectedMovable = mv;
              break;
            }
          }
        } else if (selectedMovable != null) {
          selectedMovable = null;
        }

        if ((!grid.editingGrid && movable) ||
            event.path.any(
                (e) => e is HtmlElement && e.classes.contains('controls'))) {
          return;
        }
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
      } else if (selectedPrefab != null) {
        if (!event.path.contains(_e)) return;

        var p = _evToGridSpace(event, selectedPrefab);
        movableGhost.style.left = '${p.x}px';
        movableGhost.style.top = '${p.y}px';
      }
    });
  }

  Point _evToGridSpace(
    MouseEvent event,
    EntityBase entity, {
    bool round = true,
  }) {
    var size =
        Point(entity.size * grid.cellSize / 2, entity.size * grid.cellSize / 2);

    var p = event.offset - grid.offset - size;

    if (round) {
      var cs = grid.cellSize;
      p = Point((p.x / cs).round() * cs, (p.y / cs).round() * cs);
    }
    return p;
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

  Future<Movable> addMovable(Prefab prefab, {Point pos}) async {
    var m = Movable(board: this, prefab: prefab, pos: pos);
    var id = await socket.request(a.GAME_MOVABLE_CREATE, {
      'x': m.position.x,
      'y': m.position.y,
      'prefab': prefab.id,
    });
    m.id = id;
    movables.add(m);
    grid.e.append(m.e);
    return m;
  }

  void onMovableCreate(Map<String, dynamic> json) {
    String pref = json['prefab'];
    var isPC = pref.startsWith('c');

    var m = Movable(
      board: this,
      prefab: isPC
          ? pcPrefabs[int.parse(pref.substring(1))]
          : prefabs[int.parse(pref)],
      id: json['id'],
      pos: parsePoint(json),
      size: json['size'],
    );
    movables.add(m);
    grid.e.append(m.e);
  }

  void updatePrefabImage(Prefab p, String img) {
    for (var movable in movables) {
      if (movable.prefab == p) {
        movable.onImageChange(img);
      }
    }
  }

  void onAllMovablesMove(Iterable jsons) {
    for (var mj in jsons) {
      onMovableMove(mj);
    }
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
