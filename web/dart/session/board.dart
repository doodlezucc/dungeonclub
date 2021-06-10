import 'dart:async';
import 'dart:html';
import 'dart:math';

import 'package:dnd_interactive/actions.dart' as a;
import 'package:dnd_interactive/point_json.dart';
import 'package:meta/meta.dart';

import '../communication.dart';
import '../font_awesome.dart';
import '../panels/upload.dart' as upload;
import 'condition.dart';
import 'grid.dart';
import 'map.dart';
import 'movable.dart';
import 'prefab.dart';
import 'prefab_palette.dart';
import 'roll_dice.dart';
import 'scene.dart';
import 'session.dart';

final HtmlElement _container = querySelector('#boardContainer');
final HtmlElement _e = querySelector('#board');
final ImageElement _ground = _e.querySelector('#ground');

final ButtonElement _editScene = _container.querySelector('#editScene');
final ButtonElement _exitEdit = _container.querySelector('#exitEdit');

final HtmlElement _controls = _container.querySelector('#sceneEditor');
final ButtonElement _changeImage = _controls.querySelector('#changeImage');

final HtmlElement _selectionProperties = querySelector('#selectionProperties');
final InputElement _selectedLabel = querySelector('#movableLabel');
final InputElement _selectedSize = querySelector('#movableSize');
final ButtonElement _selectedRemove = querySelector('#movableRemove');
final HtmlElement _selectedConds = _selectionProperties.querySelector('#conds');

final ButtonElement _measureToggle = querySelector('#measureDistance');
final CanvasElement _distanceCanvas = querySelector('#distanceCanvas');
final HtmlElement _distanceText = querySelector('#distanceText');

class Board {
  final Session session;
  final grid = Grid();
  final mapTab = MapTab();
  final movables = <Movable>[];

  bool get editingGrid => _container.classes.contains('edit');

  bool get measuring => _measureToggle.classes.contains('active');
  set measuring(bool measuring) {
    _container.classes.toggle('measuring', measuring);
    _distanceCanvas.classes.toggle('hidden', !measuring);
    _measureToggle.classes.toggle('active', measuring);

    if (measuring) {
      _deselectAll();
    }
  }

  Movable _selectedMovable;
  Movable get selectedMovable => _selectedMovable;
  set selectedMovable(Movable selectedMovable) {
    if (_selectedMovable == selectedMovable) return;

    _selectedMovable?.e?.classes?.remove('selected');

    if (_selectedMovable != null) {
      // Firefox doesn't automatically blurrr inputs when their parent
      // element gets moved or removed
      _selectedLabel.blur();
      _selectedSize.blur();
    }

    if (selectedMovable != null && !selectedMovable.accessible) {
      selectedMovable = null;
    }
    _selectedMovable = selectedMovable;

    if (selectedMovable != null) {
      selectedPrefab = selectedMovable.prefab;
      selectedMovable.e.classes.add('selected');

      if (selectedMovable is EmptyMovable) {
        _selectedLabel.value = selectedMovable.label;
      }

      // Assign current values to property inputs
      _selectedSize.valueAsNumber = selectedMovable.size;
      selectedMovable.e.append(_selectionProperties);
      _selectedConds.querySelectorAll('.active').classes.remove('active');
      for (var cond in selectedMovable.conds) {
        _selectedConds.children[cond].classes.add('active');
      }
    } else {
      _selectionProperties.remove();
    }
  }

  Point _position;
  Point get position => _position;
  set position(Point pos) {
    var max = Point(_ground.naturalWidth / 2, _ground.naturalHeight / 2);
    var min = Point(-max.x, -max.y);

    _position = upload.clamp(pos, min, max);
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
    _selectionProperties.style.transform = invZoomScale;
    _distanceText.style.transform = invZoomScale;

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
    _measureToggle.onClick.listen((_) => measuring = !measuring);

    _container.onMouseWheel.listen((event) {
      if (event.target is InputElement) {
        if (event.target != document.activeElement) {
          (event.target as InputElement).focus();
        }
      } else if (!mapTab.visible &&
          !event.path
              .any((e) => e is HtmlElement && e.classes.contains('controls'))) {
        zoom -= event.deltaY.sign / 3;
      }
    });

    _changeImage.onClick.listen((_) => _changeImageDialog());
    _editScene.onClick.listen((_) {
      _container.classes.add('edit');
      _deselectAll();
      measuring = false;
    });
    _exitEdit.onClick.listen((_) {
      socket.sendAction(a.GAME_SCENE_UPDATE, {
        'grid': grid.toJson(),
        'movables': movables
            .map((e) => {
                  'id': e.id,
                  ...writePoint(e.position),
                })
            .toList()
      });
      _container.classes.remove('edit');
    });

    _container.querySelector('#openMap').onClick.listen((_) {
      mapTab.visible = true;
    });

    _e.onContextMenu.listen((ev) {
      ev.preventDefault();
      _deselectAll();
    });

    window.onKeyDown.listen((ev) {
      if (ev.target is InputElement || ev.target is TextAreaElement) return;

      if (ev.keyCode == 27 && selectedPrefab != null) {
        ev.preventDefault();
        _deselectAll();
      } else if (ev.keyCode == 46 && session.isDM && selectedMovable != null) {
        _removeSelectedMovable();
      } else if (ev.key == 'm') {
        mapTab.visible = !mapTab.visible;
      }
    });

    _initSelectionHandler();
    _initSelectionConds();
    mapTab.initMapControls();
  }

  void _removeSelectedMovable() async {
    if (selectedMovable != null) {
      await socket.sendAction(a.GAME_MOVABLE_REMOVE, {
        'movable': selectedMovable.id,
      });
      selectedMovable.onRemove();
      selectedMovable = null;
    }
  }

  void _deselectAll() {
    selectedMovable = null;
    selectedPrefab = null;
  }

  void _initSelectionHandler() {
    _selectedRemove.onClick.listen((_) async {
      _removeSelectedMovable();
    });

    _listenSelectedLazyUpdate(_selectedLabel, onChange: (m, value) {
      (m as EmptyMovable).label = value;
    });
    _listenSelectedLazyUpdate(_selectedSize, onChange: (m, value) {
      m.size = int.parse(value);
    });
    _selectionProperties.remove();
  }

  void _listenSelectedLazyUpdate(
    InputElement input, {
    @required void Function(Movable m, String value) onChange,
  }) {
    String startValue;
    String typedValue;
    Movable bufferedMovable;

    void update() async {
      if (startValue != typedValue) {
        startValue = typedValue;
        onChange(bufferedMovable, typedValue);
        await socket.sendAction(
          a.GAME_MOVABLE_UPDATE,
          bufferedMovable.toJson(),
        );
      }
    }

    void onFocus() {
      startValue = input.value;
      bufferedMovable = selectedMovable;
      typedValue = input.value;
    }

    input.onMouseDown.listen((_) {
      // Firefox number inputs can trigger onInput without being focused
      var isFocused = document.activeElement == input;
      if (!isFocused) {
        input.focus();
        onFocus();
      }
    });

    input.onFocus.listen((_) => onFocus());
    input.onInput.listen((_) {
      typedValue = input.value;
      onChange(bufferedMovable, typedValue);
    });
    input.onBlur.listen((_) => update());
    input.onChange.listen((_) => update());
  }

  void _initDragControls() {
    void alignDistanceText(MouseEvent event, num distance) {
      var p = event.offset;
      _distanceText.style.left = '${p.x}px';
      _distanceText.style.top = '${p.y}px';
      _distanceText.text = grid.tileUnitString(distance);
    }

    var isBoardDrag = false;
    var drag = false;
    var button = -1;
    Point measureStart;
    Point measureStartScaled;
    Timer timer;
    _container.onMouseDown.listen((event) async {
      if (mapTab.visible) return;

      button = event.button;
      isBoardDrag = event.path.contains(_e);

      if (isBoardDrag && button == 0) {
        timer = Timer(Duration(milliseconds: 300), () {
          var pos = (event.page - _e.getBoundingClientRect().topLeft) *
              (1 / scaledZoom);
          socket.sendAction(a.GAME_PING, writePoint(pos));
          displayPing(pos);
        });
      }

      if (measuring && button == 0) {
        if (isBoardDrag) {
          measureStart = grid.evToGridSpaceUnscaled(event);
          measureStartScaled = grid.roundToCell(event.offset);
          _distanceText.classes.remove('hidden');
          alignDistanceText(event, 0);
          _redrawDistanceCanvas(measureStartScaled, measureStartScaled);
        }
        return;
      }

      var movable = event.path
          .any((e) => e is HtmlElement && e.classes.contains('movable'));

      if (button == 0 && !editingGrid) {
        if (movable) {
          for (var mv in movables) {
            if (mv.e == event.target) {
              alignMovableGhost(event, mv);
              selectedMovable = mv;
              break;
            }
          }
          return;
        } else if (isBoardDrag) {
          if (selectedPrefab != null) {
            var gridPos = grid.evToGridSpace(event, selectedPrefab.size);
            selectedMovable = await addMovable(selectedPrefab, pos: gridPos);
          }
        }
      }

      if (event.path
          .any((e) => e is HtmlElement && e.classes.contains('controls'))) {
        return;
      }

      drag = true;
      await window.onMouseUp.first;
      drag = false;
    });
    window.onMouseMove.listen((event) {
      timer?.cancel();
      var parentIsBoard =
          event.target is Element && (event.target as Element).parent == _e;

      if (drag) {
        var delta = event.movement * (1 / _scaledZoom);

        position += delta;
      } else if (measuring && measureStart != null && parentIsBoard) {
        var measureEnd = grid.evToGridSpaceUnscaled(event);
        // Using Chebychov method
        var distance = max(
          (measureEnd.x - measureStart.x).abs(),
          (measureEnd.y - measureStart.y).abs(),
        );
        alignDistanceText(event, distance);

        _redrawDistanceCanvas(
            measureStartScaled, grid.roundToCell(event.offset));
      } else if (selectedPrefab != null) {
        if (!parentIsBoard) {
          toggleMovableGhostVisible(false);
        } else {
          alignMovableGhost(event, selectedPrefab);
          toggleMovableGhostVisible(true);
        }
      }
    });
    window.onMouseUp.listen((event) {
      timer?.cancel();
      if (measuring && event.button == 0) {
        measureStart = null;
        _distanceCanvas.context2D
            .clearRect(0, 0, _ground.naturalWidth, _ground.naturalHeight);
        _distanceText.classes.add('hidden');
      }
    });
  }

  void _initSelectionConds() {
    var conds = Condition.items;
    for (var i = 0; i < conds.length; i++) {
      var cond = conds[i];
      var ico = icon(cond.icon)..append(SpanElement()..text = cond.name);

      _selectedConds.append(ico
        ..onClick.listen((_) {
          ico.classes.toggle('active', _selectedMovable.toggleCondition(i));

          socket.sendAction(a.GAME_MOVABLE_UPDATE, _selectedMovable.toJson());
        }));
    }

    _selectionProperties.querySelector('a').onClick.listen((_) {
      if (_selectedMovable.conds.isNotEmpty) {
        _selectedMovable.applyConditions([]);
        _selectedConds.querySelectorAll('.active').classes.remove('active');
        socket.sendAction(a.GAME_MOVABLE_UPDATE, _selectedMovable.toJson());
      }
    });
  }

  void displayPing(Point p) async {
    var ping = DivElement()
      ..className = 'ping'
      ..style.left = '${p.x}px'
      ..style.top = '${p.y}px';
    _e.append(ping);
    await Future.delayed(Duration(seconds: 3));
    ping.remove();
  }

  void _redrawDistanceCanvas(Point start, Point end) {
    var ctx = _distanceCanvas.context2D;
    ctx.clearRect(0, 0, _ground.naturalWidth, _ground.naturalHeight);
    ctx.strokeStyle = '#ffffff';
    ctx.lineWidth = max(2 / scaledZoom, 2);
    ctx.beginPath();
    ctx.moveTo(start.x, start.y);
    ctx.lineTo(end.x, end.y);
    ctx.closePath();
    ctx.stroke();

    var circleSize = max(5 / scaledZoom, 5);

    ctx.fillStyle = '#ffffff';
    ctx.beginPath();
    ctx.arc(start.x, start.y, circleSize, 0, 2 * pi);
    ctx.arc(end.x, end.y, circleSize, 0, 2 * pi);
    ctx.fill();
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
        'scale($scaledZoom) translate(${position.x}px, ${position.y}px)';
  }

  void onImgChange({String src, bool updateRef = true}) async {
    src = src ?? Scene.getSceneImage(_sceneId);
    src += '?${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
    _ground.src = src;
    if (updateRef) {
      refScene?.image = src;
    }
    await _ground.onLoad.first;
    _distanceCanvas.width = _ground.naturalWidth;
    _distanceCanvas.height = _ground.naturalHeight;
    grid.resize(_ground.naturalWidth, _ground.naturalHeight);
  }

  void clear() {
    movables.forEach((m) => m.e.remove());
    movables.clear();
  }

  Future<Movable> addMovable(Prefab prefab, {Point pos}) async {
    var id = await socket.request(a.GAME_MOVABLE_CREATE, {
      'x': pos.x,
      'y': pos.y,
      'prefab': prefab.id,
    });
    var m = Movable.create(
        board: this, prefab: prefab, id: id, pos: pos, conds: []);
    movables.add(m);
    grid.e.append(m.e);
    return m;
  }

  void onMovableCreate(Map<String, dynamic> json) {
    String pref = json['prefab'];
    var isEmpty = pref[0] == 'e';

    var m = Movable.create(
      board: this,
      prefab: isEmpty ? emptyPrefab : getPrefab(pref),
      id: json['id'],
      pos: parsePoint(json),
      conds: List<int>.from(json['conds'] ?? []),
    )..fromJson(json);
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

  void _movableEvent(json, void Function(Movable m) action) {
    for (var m in movables) {
      if (m.id == json['movable']) {
        return action(m);
      }
    }
  }

  void onMovableMove(json) =>
      _movableEvent(json, (m) => m.onMove(parsePoint(json)));

  void onMovableRemove(json) => _movableEvent(json, (m) => m.onRemove());

  void onMovableUpdate(json) => _movableEvent(json, (m) => m.fromJson(json));

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
