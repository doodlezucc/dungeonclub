import 'dart:async';
import 'dart:html';
import 'dart:math';
import 'dart:svg' as svg;

import 'package:dnd_interactive/actions.dart' as a;
import 'package:dnd_interactive/point_json.dart';
import 'package:meta/meta.dart';

import '../communication.dart';
import '../font_awesome.dart';
import '../notif.dart';
import '../panels/upload.dart' as upload;
import 'condition.dart';
import 'fog_of_war.dart';
import 'grid.dart';
import 'log.dart';
import 'initiative_tracker.dart';
import 'map.dart';
import 'measuring.dart';
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

final svg.RectElement _selectionArea = _e.querySelector('#selectionArea');
final HtmlElement _selectionProperties = querySelector('#selectionProperties');
final InputElement _selectedLabel = querySelector('#movableLabel');
final InputElement _selectedSize = querySelector('#movableSize');
final ButtonElement _selectedRemove = querySelector('#movableRemove');
final HtmlElement _selectedConds = _selectionProperties.querySelector('#conds');

final ButtonElement _fowToggle = querySelector('#fogOfWar');
final ButtonElement _measureToggle = querySelector('#measureDistance');

class Board {
  final Session session;
  final grid = Grid();
  final mapTab = MapTab();
  final movables = <Movable>[];
  final selected = <Movable>{};
  final fogOfWar = FogOfWar();
  List<Movable> clipboard = [];

  static const PAN = 'pan';
  static const MEASURE = 'measure';
  static const FOG_OF_WAR = 'fow';

  set showInactiveSceneWarning(bool v) => _container
      .querySelector('#inactiveSceneWarning')
      .classes
      .toggle('hidden', !v);

  bool get editingGrid => _container.classes.contains('edit');
  set editingGrid(bool v) {
    _container.classes.toggle('edit', v);

    if (v) {
      _deselectAll();
      mode = PAN;
    } else {
      socket.sendAction(a.GAME_SCENE_UPDATE, {
        'grid': grid.toJson(),
        'movables': movables
            .map((e) => {
                  'id': e.id,
                  ...writePoint(e.position),
                })
            .toList()
      });
      rescaleMeasurings();
    }
  }

  String _mode;
  String get mode => _mode;
  set mode(String mode) {
    if (mode == _mode) mode = PAN;

    _mode = mode;

    var isPan = mode == PAN;
    _container.attributes['mode'] = '$mode';
    _measureToggle.classes.toggle('active', mode == MEASURE);
    _fowToggle.classes.toggle('active', mode == FOG_OF_WAR);
    fogOfWar.canvas.captureInput = mode == FOG_OF_WAR;

    if (!isPan) {
      _deselectAll();

      if (mode == MEASURE) {
        displayTooltip(getMeasureTooltip());
      } else {
        displayTooltip('''Hold left click to draw continuous shapes or click
                          once<br> to add individual points. Hold shift to
                          make holes.''');
      }
    } else {
      displayTooltip('');
    }
  }

  Movable _activeMovable;
  Movable get activeMovable => _activeMovable;
  set activeMovable(Movable activeMovable) {
    if (_activeMovable == activeMovable) return;

    if (_activeMovable != null) {
      // Firefox doesn't automatically blurrr inputs when their parent
      // element gets moved or removed
      _selectedLabel.blur();
      _selectedSize.blur();
      _activeMovable.e.classes.remove('active');
    }

    if (activeMovable != null && !activeMovable.accessible) {
      activeMovable = null;
    }
    _activeMovable = activeMovable;

    if (activeMovable != null) {
      activeMovable.e.classes.add('active');

      // Assign current values to HTML inputs
      if (activeMovable is EmptyMovable) {
        _selectedLabel.value = activeMovable.label;
        _selectionProperties.classes.add('empty');
      } else {
        _selectionProperties.classes.remove('empty');
      }

      _selectedSize.valueAsNumber = activeMovable.size;
      _updateSelectionSizeInherit();
      _selectedConds.querySelectorAll('.active').classes.remove('active');
      for (var cond in activeMovable.conds) {
        _selectedConds.children[cond].classes.add('active');
      }
    }

    _selectionProperties.classes.toggle('hidden', activeMovable == null);
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
    querySelectorAll('.distance-text').style.transform = invZoomScale;

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
    _initMouseControls();
    initDiceTable();
    initGameLog();
    initInitiativeTracker();
    _measureToggle.onClick.listen((_) => mode = MEASURE);
    measureMode = 0;
    _measureToggle.onClick.listen((ev) {
      var target = ev.target;

      if (target is HtmlElement) {
        var mMode = target.getAttribute('mode');
        if (mMode != null) {
          var oldMode = measureMode;
          measureMode = int.parse(mMode);
          displayTooltip(getMeasureTooltip());

          // Prevent mode toggle
          if (mode == MEASURE && measureMode != oldMode) return null;
        }
      }

      mode = MEASURE;
    });
    _fowToggle.onClick.listen((_) => mode = FOG_OF_WAR);

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
    _editScene.onClick.listen((_) => editingGrid = true);
    _exitEdit.onClick.listen((_) => editingGrid = false);

    _container.querySelector('#inactiveSceneWarning').onClick.listen((_) {
      refScene.enterPlay();
    });

    _container.querySelector('#openMap').onClick.listen((_) {
      mapTab.visible = true;
    });

    _container.onContextMenu.listen((ev) {
      ev.preventDefault();
      _deselectAll();
    });

    window.onKeyDown.listen((ev) {
      if (ev.target is InputElement || ev.target is TextAreaElement) return;

      if (ev.keyCode == 27) {
        // Escape
        if (selectedPrefab != null) {
          ev.preventDefault();
          _deselectAll();
        } else if (mode != PAN) {
          Future.delayed(Duration(milliseconds: 4), () {
            // Event might be handled by polymask or map view
            if (!ev.defaultPrevented) {
              mode = PAN;
              ev.preventDefault();
            }
          });
        }
      } else if (ev.key == 'm') {
        mapTab.visible = !mapTab.visible;
      } else if (session.isDM) {
        if (ev.keyCode == 46 || ev.keyCode == 8) {
          // Delete/Backspace
          ev.preventDefault();
          _removeSelectedMovables();
        }
        // Paste from clipboard
        else if (ev.key == 'v') {
          ev.preventDefault();
          if (clipboard.isNotEmpty) {
            cloneMovables(clipboard);
          }
        }
        // Copy to clipboard or duplicate
        else if (selected.isNotEmpty) {
          if (ev.ctrlKey) {
            // Copy with Ctrl+C
            if (ev.key == 'c') {
              ev.preventDefault();
              clipboard = selected.toList();
            }
            // Cut with Ctrl+X
            else if (ev.key == 'x') {
              ev.preventDefault();
              clipboard = selected.toList();
              _removeSelectedMovables();
            }
          }
          // Duplicate with Shift+D
          else if (ev.key == 'D') {
            cloneMovables(selected);
          }
        }
      }
    });

    _initSelectionHandler();
    _initSelectionConds();
    mapTab.initMapControls();
    fogOfWar.initFogOfWar(this);
  }

  void toggleSelect(Iterable<Movable> movables,
      {bool additive = false, bool state}) {
    if (!additive) {
      _deselectAll();
    }

    state ??= !movables.any((m) => selected.contains(m));

    movables.forEach((m) {
      if (m.e.classes.toggle('selected', state)) {
        selected.add(m);
      } else {
        selected.remove(m);

        if (m == activeMovable) activeMovable = null;
      }
    });

    if (state && movables.length == 1) {
      activeMovable = movables.first;
    }
  }

  void _removeSelectedMovables() async {
    await socket.sendAction(a.GAME_MOVABLE_REMOVE, {
      'movables': selected.map((m) => m.id).toList(),
    });

    for (var m in selected) {
      m.onRemove();
      movables.remove(m);
      if (m == activeMovable) {
        activeMovable = null;
      }
    }
    selected.clear();
  }

  void _deselectAll() {
    for (var m in selected) {
      m.e.classes.remove('selected');
    }
    selected.clear();
    activeMovable = null;
    selectedPrefab = null;
  }

  void _updateSelectionSizeInherit() {
    _selectedSize.parent.children.last.style.display =
        activeMovable.size == 0 ? '' : 'none';
  }

  void _initSelectionHandler() {
    _selectedRemove.onClick.listen((_) async {
      _removeSelectedMovables();
    });

    _listenSelectedLazyUpdate(_selectedLabel, onChange: (m, value) {
      (m as EmptyMovable).label = value;
    });
    _listenSelectedLazyUpdate(_selectedSize, onChange: (m, value) {
      m.size = int.parse(value);
      _updateSelectionSizeInherit();
    });
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
      bufferedMovable = activeMovable;
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

  void _initMouseControls() {
    StreamController<SimpleEvent> moveStreamCtrl;
    Timer timer;
    Point previous;
    int initialButton;

    void listenToCursorEvents<T extends Event>(
      Point Function(T ev) evToPoint,
      Stream<T> startEvent,
      Stream<T> moveEvent,
      Stream<T> endEvent,
    ) {
      SimpleEvent toSimple(T ev) {
        var delta = evToPoint(ev) - previous;
        previous = evToPoint(ev);
        return SimpleEvent(
          previous - _e.getBoundingClientRect().topLeft,
          delta,
          (ev as dynamic).shiftKey,
          (ev as dynamic).ctrlKey,
          ev is MouseEvent ? ev.button : 0,
        );
      }

      startEvent.listen((ev) async {
        if (mapTab.visible ||
            ev.path
                .any((e) => e is Element && e.classes.contains('controls'))) {
          return;
        }

        ev.preventDefault();
        document.activeElement.blur();

        previous = evToPoint(ev);
        var start = toSimple(ev);

        if (start.button != initialButton && moveStreamCtrl != null) {
          return moveStreamCtrl.add(start);
        }

        initialButton = start.button;
        var isBoardDrag = ev.path.contains(_e);

        if (mode == PAN && isBoardDrag) {
          timer = Timer(Duration(milliseconds: 300), () {
            var pos = start.p * (1 / scaledZoom);

            socket.sendAction(a.GAME_PING, {
              ...writePoint(pos),
              'player': session.charId,
            });
            displayPing(pos, session.charId);
          });
        }

        moveStreamCtrl = StreamController();
        var stream = moveStreamCtrl.stream;

        var pan = !(start.button == 0 && mode != PAN);

        Movable clickedMovable;

        if (start.button == 0) {
          if (mode == MEASURE) {
            _handleMeasuring(start, stream, measureMode);
          } else if (mode == PAN) {
            if (start.ctrl) {
              _handleSelectArea(start, stream);
              pan = false;
            } else {
              var movableElem = ev.path.firstWhere(
                (e) =>
                    e is Element &&
                    e.classes.contains('movable') &&
                    e.classes.contains('accessible'),
                orElse: () => null,
              );

              if (movableElem != null) {
                for (var mv in movables) {
                  if (mv.e == movableElem) {
                    clickedMovable = mv;
                    break;
                  }
                }

                _handleMovableMove(start, stream, clickedMovable);
                pan = false;
              } else if (selectedPrefab != null) {
                var gridPos = grid.offsetToGridSpace(
                    start.p * (1 / scaledZoom), selectedPrefab.size);

                var newMov = await addMovable(selectedPrefab, gridPos);

                if (newMov != null) {
                  toggleSelect([newMov], state: true);
                  pan = false;
                  if (newMov is EmptyMovable) {
                    Future.delayed(Duration(milliseconds: 4),
                        () => _selectedLabel.focus());
                  }
                }
              } else if (!start.shift) {
                _deselectAll();
              }
            }
          }
        }

        if (pan) {
          _handlePanning(start, stream);
        }

        await endEvent.firstWhere((ev) => toSimple(ev).button == initialButton);

        var isClickEvent = false;
        if (timer != null && timer.isActive) {
          timer.cancel();
          isClickEvent = true;
        }

        if (clickedMovable != null) {
          toggleSelect(
            [clickedMovable],
            additive: !isClickEvent || (ev as dynamic).shiftKey,
            state: isClickEvent ? null : true,
          );
        }

        var streamCopy = moveStreamCtrl;
        moveStreamCtrl = null;
        await streamCopy.close();
      });

      moveEvent.listen((ev) {
        if (moveStreamCtrl != null) {
          timer?.cancel();
          moveStreamCtrl.add(toSimple(ev));
        } else {
          if (selectedPrefab != null) {
            var p = evToPoint(ev) - _e.getBoundingClientRect().topLeft;
            alignMovableGhost(p * (1 / scaledZoom), selectedPrefab);
            toggleMovableGhostVisible(true);
          }
        }
      });
    }

    listenToCursorEvents<MouseEvent>((ev) => ev.page, _container.onMouseDown,
        window.onMouseMove, window.onMouseUp);

    listenToCursorEvents<TouchEvent>((ev) => ev.targetTouches[0].page,
        _container.onTouchStart, window.onTouchMove, window.onTouchEnd);
  }

  void _handleSelectArea(SimpleEvent first, Stream<SimpleEvent> moveStream) {
    void setAnimLen(svg.AnimatedLength len, num v) =>
        len.baseVal.newValueSpecifiedUnits(svg.Length.SVG_LENGTHTYPE_PX, v);

    var p = first.p * (1 / scaledZoom);
    var q = p;

    void scaleArea() {
      var rect = Rectangle.fromPoints(p, q);
      setAnimLen(_selectionArea.x, rect.left);
      setAnimLen(_selectionArea.y, rect.top);
      _selectionArea.style.width = '${rect.width}px';
      _selectionArea.style.height = '${rect.height}px';
    }

    moveStream.listen((ev) {
      q += ev.movement * (1 / scaledZoom);
      scaleArea();
    }, onDone: () {
      // Select area
      if (!first.shift) _deselectAll();
      _selectMovablesInScreenRect(Rectangle.fromPoints(p, q));
      q = p;
      scaleArea();
    });
  }

  void _selectMovablesInScreenRect(Rectangle r) {
    Point scale(Point p) => grid.offsetToGridSpaceUnscaled(p,
        round: false, offset: const Point(0, 0));

    var rect = Rectangle.fromPoints(scale(r.topLeft), scale(r.bottomRight));

    var validMovables = movables.where((m) {
      if (!m.accessible) return false;
      var mRect = Rectangle(
        m.position.x,
        m.position.y,
        m.displaySize,
        m.displaySize,
      );
      return rect.intersects(mRect);
    }).toList();

    toggleSelect(validMovables, additive: true);
  }

  void _handlePanning(SimpleEvent first, Stream<SimpleEvent> moveStream) {
    moveStream.listen((ev) {
      position += ev.movement * (1 / scaledZoom);
    });
  }

  void _handleMovableMove(
      SimpleEvent first, Stream<SimpleEvent> moveStream, Movable extra) {
    toggleMovableGhostVisible(false);
    var off = Point<num>(0, 0);
    var starts = <Movable, Point>{};
    var movedOnce = false;
    var affected = {extra, ...selected};

    for (var mv in affected) {
      starts[mv] = mv.position;
    }

    Point rounded() {
      return scalePoint(off, (v) => (v / grid.cellSize).round());
    }

    moveStream.listen((ev) {
      if (!movedOnce) {
        movedOnce = true;
        if (!extra.e.classes.contains('selected') && !first.shift) {
          _deselectAll();
          affected = {extra};
        }
      }
      off += ev.movement * (1 / scaledZoom);

      var delta = rounded();

      for (var mv in affected) {
        mv.position = starts[mv] + delta;
      }
    }, onDone: () {
      if (rounded() != Point(0, 0)) {
        return socket.sendAction(a.GAME_MOVABLE_MOVE, {
          'movables': affected.map((e) => e.id).toList(),
          ...writePoint(rounded())
        });
      }
    });
  }

  void _handleMeasuring(
      SimpleEvent first, Stream<SimpleEvent> moveStream, int type) {
    var p = first.p * (1 / scaledZoom);

    var offset = type == MEASURING_PATH ? Point(0.5, 0.5) : Point(0.0, 0.0);

    Point origin;
    if (type == MEASURING_LINE) {
      origin = grid.offsetToGridSpaceUnscaled(p * 2, offset: Point(1, 1)) * 0.5;
    } else {
      origin = grid.offsetToGridSpaceUnscaled(p, offset: offset) -
          Point(0.5, 0.5) +
          offset;
    }

    var m = Measuring.create(type, origin, session.charId);
    sendCreationEvent(type, origin);
    m.alignDistanceText(p);
    zoom = zoom; // Rescale distance text

    Point measureEnd;
    var hasChanged = false;

    var syncTimer = Timer.periodic(Duration(milliseconds: 100), (_) {
      if (hasChanged) {
        hasChanged = false;
        m.sendUpdateEvent(measureEnd);
      }
    });

    var keySub = window.onKeyDown.listen((ev) {
      // Space
      if (ev.keyCode == 32) {
        m.addPoint(measureEnd);
      }
    });

    moveStream.listen((ev) {
      p = ev.p * (1 / scaledZoom);
      measureEnd = grid.offsetToGridSpaceUnscaled(
        p,
        round: false,
        offset: Point(0.5, 0.5) - offset,
      );
      if (ev.button == 2) {
        m.addPoint(measureEnd);
      }
      m.redraw(measureEnd);
      m.alignDistanceText(p);
      hasChanged = true;
    }, onDone: () {
      keySub.cancel();
      syncTimer.cancel();
      m.dispose();
      m.sendRemovalEvent();
    });
  }

  void _initSelectionConds() {
    var conds = Condition.items;
    for (var i = 0; i < conds.length; i++) {
      var cond = conds[i];
      var ico = icon(cond.icon)..append(SpanElement()..text = cond.name);

      _selectedConds.append(ico
        ..onClick.listen((_) {
          ico.classes.toggle('active', _activeMovable.toggleCondition(i));

          socket.sendAction(a.GAME_MOVABLE_UPDATE, _activeMovable.toJson());
        }));
    }

    _selectionProperties.querySelector('a').onClick.listen((_) {
      if (_activeMovable.conds.isNotEmpty) {
        _activeMovable.applyConditions([]);
        _selectedConds.querySelectorAll('.active').classes.remove('active');
        socket.sendAction(a.GAME_MOVABLE_UPDATE, _activeMovable.toJson());
      }
    });
  }

  void displayTooltip(String text) {
    _container.querySelector('#tooltip').innerHtml = text;
  }

  void displayPing(Point p, int player) async {
    var ping = DivElement()
      ..className = 'ping'
      ..style.left = '${p.x}px'
      ..style.top = '${p.y}px'
      ..style.borderColor = session.getPlayerColor(player);
    _e.append(ping);
    await Future.delayed(Duration(seconds: 3));
    ping.remove();
  }

  void _changeImageDialog() async {
    var img = await upload.display(
      action: a.GAME_SCENE_UPDATE,
      type: a.IMAGE_TYPE_SCENE,
      extras: {
        'id': _sceneId,
      },
    );

    if (img != null) {
      await onImgChange(src: img);
    }
  }

  void _transform() {
    _e.style.transform =
        'scale($scaledZoom) translate(${position.x}px, ${position.y}px)';
  }

  Future<void> onImgChange({String src, bool updateRef = true}) async {
    src = src ?? Scene.getSceneImage(_sceneId);
    src += '?${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
    _ground.src = src;
    if (updateRef) {
      refScene?.image = src;
    }
    await _ground.onLoad.first;
    grid.resize(_ground.naturalWidth, _ground.naturalHeight);
    fogOfWar.fixSvgInit(_ground.naturalWidth, _ground.naturalHeight);
  }

  void clear() {
    _deselectAll();
    movables.forEach((m) => m.e.remove());
    movables.clear();
  }

  void _syncMovableAnim() async {
    var elems = _e.querySelectorAll('.movable .ring');
    for (var m in elems) {
      m.style.animation = 'none';
      m.innerText; // Trigger reflow
    }
    for (var m in elems) {
      m.style.animation = '';
    }
  }

  Future<void> cloneMovables(Iterable<Movable> source) async {
    var jsons = source.map((m) => m.toCloneJson());

    var result = await socket.request(a.GAME_MOVABLE_CREATE_ADVANCED, {
      'movables': jsons.toList(),
    });

    if (result == null) {
      return _onMovableCountLimitReached();
    }

    var ids = List<int>.from(result);

    var dest = <Movable>[];
    for (var i = 0; i < ids.length; i++) {
      var src = source.elementAt(i);

      var m = Movable.create(
        board: this,
        prefab: src.prefab,
        id: ids[i],
        pos: src.position,
        conds: src.conds,
      );

      if (src is EmptyMovable) {
        (m as EmptyMovable).label = src.label;
      }

      dest.add(m);
      movables.add(m);
      grid.e.append(m.e);
    }
    _deselectAll();
    _syncMovableAnim();
    toggleSelect(dest, state: true);
  }

  Future<Movable> addMovable(Prefab prefab, Point pos) async {
    var id = await socket.request(a.GAME_MOVABLE_CREATE, {
      ...writePoint(pos),
      'prefab': prefab.id,
    });

    if (id == null) {
      _onMovableCountLimitReached();
      return null;
    }

    var m = Movable.create(
        board: this, prefab: prefab, id: id, pos: pos, conds: []);
    movables.add(m);
    grid.e.append(m.e);
    _syncMovableAnim();
    return m;
  }

  void _onMovableCountLimitReached() {
    HtmlNotification('Limit of 50 movables reached.').display();
    _deselectAll();
  }

  void onMovableCreateAdvanced(Map<String, dynamic> json) {
    for (var m in json['movables']) {
      onMovableCreate(m);
    }
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
    List ids = json['movables'] ?? [json['movable']];

    for (var m in List.from(movables)) {
      if (ids.contains(m.id)) {
        action(m);
      }
    }
  }

  void onMovableMove(json) =>
      _movableEvent(json, (m) => m.onMove(parsePoint(json)));

  void onMovableRemove(json) => _movableEvent(json, (m) {
        if (selected.contains(m)) {
          toggleSelect([m], additive: true, state: false);
        }
        m.onRemove();
      });

  void onMovableUpdate(json) => _movableEvent(json, (m) => m.fromJson(json));

  void rescaleMeasurings() {
    var x = grid.tiles;
    var y = x * (_ground.height / _ground.width);
    measuringRoot.setAttribute('viewBox', '-0.5 -0.5 $x $y');
  }

  void fromJson(int id, Map<String, dynamic> json) async {
    clear();

    _sceneId = id;
    await onImgChange(updateRef: false);

    mode = PAN;

    fogOfWar.load(json['fow']);
    grid.fromJson(json['grid']);
    rescaleMeasurings();

    for (var m in json['movables']) {
      onMovableCreate(m);
    }

    zoom = -0.5;
    position = Point(0, 0);
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
