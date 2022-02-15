import 'dart:async';
import 'dart:html';
import 'dart:svg' as svg;

import 'package:dnd_interactive/actions.dart' as a;
import 'package:dnd_interactive/limits.dart';
import 'package:dnd_interactive/point_json.dart';
import 'package:meta/meta.dart';

import '../communication.dart';
import '../font_awesome.dart';
import '../html_transform.dart';
import '../lazy_input.dart';
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
final InputElement _selectedAura = querySelector('#movableAura');
final ButtonElement _selectedInvisible = querySelector('#movableInvisible');
final ButtonElement _selectedRemove = querySelector('#movableRemove');
final HtmlElement _selectedConds = _selectionProperties.querySelector('#conds');

final ButtonElement _fowToggle = querySelector('#fogOfWar');
final ButtonElement _measureToggle = querySelector('#measureDistance');
HtmlElement get _measureSticky => querySelector('#measureSticky');
HtmlElement get _measureVisible => querySelector('#measureVisible');

class Board {
  final Session session;
  final grid = Grid();
  final mapTab = MapTab();
  final movables = <Movable>[];
  final selected = <Movable>{};
  final fogOfWar = FogOfWar();
  final initiativeTracker = InitiativeTracker();
  List<Movable> clipboard = [];

  static const PAN = 'pan';
  static const MEASURE = 'measure';
  static const FOG_OF_WAR = 'fow';

  final transform = BoardTransform(
    _e,
    getMaxPosition: () => Point(
      _ground.naturalWidth,
      _ground.naturalHeight,
    ),
  );

  Point get position => transform.position;
  set position(Point p) => transform.position = p;

  double get zoom => transform.zoom;
  set zoom(double zoom) => transform.zoom = zoom;

  double get scaledZoom => transform.scaledZoom;

  set showInactiveSceneWarning(bool v) {
    initiativeTracker.disabled = v;
    _container
        .querySelector('#inactiveSceneWarning')
        .classes
        .toggle('hidden', !v);
  }

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

  bool get measureVisible => _measureVisible.classes.contains('active');
  set measureVisible(bool v) {
    _measureVisible
      ..className = 'fas fa-' + (v ? 'eye active' : 'eye-slash')
      ..querySelector('span').text = v ? 'Public' : 'Private';

    removeMeasuring(session.charId, sendEvent: true);
  }

  String _mode;
  String get mode => _mode;
  set mode(String mode) {
    if (mode == _mode) mode = PAN;

    if (_mode == MEASURE) {
      // Exiting measure mode
      removeMeasuring(session.charId, sendEvent: true);
    }

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

      _selectedAura.valueAsNumber = activeMovable.auraRadius;
      _updateSelectedInvisible(activeMovable.invisible);
      _selectedSize.valueAsNumber = activeMovable.size;
      _updateSelectionSizeInherit();
      _selectedConds.querySelectorAll('.active').classes.remove('active');
      for (var cond in activeMovable.conds) {
        _selectedConds.children[cond].classes.add('active');
      }
    }

    _selectionProperties.classes.toggle('hidden', activeMovable == null);
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

  void _toggleMeasureSticky() {
    if (!_measureSticky.classes.toggle('active')) {
      removeMeasuring(session.charId, sendEvent: true);
    }
  }

  void _initBoard() {
    _initMouseControls();
    initDiceTable();
    initGameLog();
    initiativeTracker.init(session.isDM);
    measureVisible = true;
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
        } else if (target == _measureSticky) {
          return _toggleMeasureSticky();
        } else if (target == _measureVisible) {
          measureVisible = !measureVisible;
          return;
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
        transform.handleMousewheel(event);
      }
    });

    _changeImage.onLMB.listen(_changeImageDialog);
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

    state ??=
        activeMovable == null || !movables.any((m) => selected.contains(m));

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
    if (mapTab.visible) return;

    await socket.sendAction(a.GAME_MOVABLE_REMOVE, {
      'movables': selected.map((m) => m.id).toList(),
    });

    for (var m in selected) {
      m.onRemove();
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

  void _sendSelectedMovablesUpdate() {
    socket.sendAction(a.GAME_MOVABLE_UPDATE, {
      'changes': selected.map((e) => e.toJson()).toList(),
    });
  }

  void _updateSelectedInvisible(bool v) {
    _selectedInvisible.classes.toggle('active', v);
    _selectedInvisible.querySelector('span').text = v ? 'Invisible' : 'Visible';
    _selectedInvisible.querySelector('i').className =
        'fas fa-' + (v ? 'eye-slash' : 'eye');
  }

  void _initSelectionHandler() {
    _selectedRemove.onClick.listen((_) async {
      _removeSelectedMovables();
    });

    _listenSelectedLazyUpdate(_selectedLabel, onChange: (m, value) {
      if (m is EmptyMovable) {
        m.label = value;
      }
    });
    _listenSelectedLazyUpdate(_selectedAura, onChange: (m, value) {
      m.auraRadius = double.parse(value);
    });
    _selectedInvisible.onClick.listen((_) {
      var inv = !_selectedInvisible.classes.contains('active');
      _updateSelectedInvisible(inv);
      selected.forEach((m) => m.invisible = inv);
      _sendSelectedMovablesUpdate();
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
    listenLazyUpdate(
      input,
      onChange: (value) => selected.forEach((m) => onChange(m, value)),
      onSubmit: (value) => _sendSelectedMovablesUpdate(),
    );
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
        previous = evToPoint(ev);
        var start = toSimple(ev);

        if (mapTab.visible ||
            (editingGrid &&
                start.button == 0 &&
                ev.path.any((e) => e is Element && e.id == 'gridPadding')) ||
            ev.path
                .any((e) => e is Element && e.classes.contains('controls'))) {
          return;
        }

        ev.preventDefault();
        document.activeElement.blur();

        if (start.button != initialButton && moveStreamCtrl != null) {
          return moveStreamCtrl.add(start);
        }

        initialButton = start.button;
        var isBoardDrag = ev.path.contains(_e);

        if (mode == PAN && isBoardDrag && initialButton == 0) {
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

        if (start.ctrl && initialButton == 1) {
          transform.handleFineZooming(start, stream);
        } else if (pan) {
          transform.handlePanning(start, stream);
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
      var mRect =
          Rectangle(m.position.x, m.position.y, m.displaySize, m.displaySize);
      return rect.intersects(mRect);
    }).toList();

    toggleSelect(validMovables, additive: true);
  }

  void _handleMovableMove(
      SimpleEvent first, Stream<SimpleEvent> moveStream, Movable extra) {
    toggleMovableGhostVisible(false);
    var off = Point<num>(0, 0);
    var movedOnce = false;
    var affected = {extra, ...selected};

    Point rounded() => scalePoint(off, (v) => (v / grid.cellSize).round());

    var lastDelta = rounded();

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

      if (delta != lastDelta) {
        for (var mv in affected) {
          mv.position += delta - lastDelta;
        }
        lastDelta = delta;
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
    var isPublic = measureVisible;
    var p = first.p * (1 / scaledZoom);

    var doOffset = type != MEASURING_CUBE && first.shift;
    if (type == MEASURING_PATH) doOffset = !doOffset;

    var offset = doOffset ? Point(0.5, 0.5) : Point(0.0, 0.0);

    var origin = grid.offsetToGridSpaceUnscaled(p, offset: offset) -
        Point(0.5, 0.5) +
        offset;

    removeMeasuring(session.charId, sendEvent: true);
    var m = Measuring.create(type, origin, session.charId);
    m.alignDistanceText(p);
    zoom += 0; // Rescale distance text

    if (isPublic) sendCreationEvent(type, origin, p);

    Point measureEnd;
    var hasChanged = false;

    var syncTimer = Timer.periodic(Duration(milliseconds: 100), (_) {
      if (hasChanged && isPublic) {
        hasChanged = false;
        m.sendUpdateEvent(measureEnd);
      }
    });

    var keySub = window.onKeyDown.listen((ev) {
      if (ev.keyCode == 32) {
        m.addPoint(measureEnd); // Trigger with spacebar
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
      } else if (ev.button == 1) {
        _measureSticky.classes.toggle('active');
      }

      m.redraw(measureEnd);
      m.alignDistanceText(p);
      hasChanged = true;
    }, onDone: () {
      keySub.cancel();
      syncTimer.cancel();
      if (!_measureSticky.classes.contains('active')) {
        removeMeasuring(session.charId, sendEvent: isPublic);
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
          var activate = !_activeMovable.conds.contains(i);
          selected.forEach((m) => m.toggleCondition(i, activate));
          ico.classes.toggle('active', activate);
          _sendSelectedMovablesUpdate();
        }));
    }

    _selectionProperties.querySelector('a').onClick.listen((_) {
      if (_activeMovable.conds.isNotEmpty) {
        selected.forEach((m) => m.applyConditions([]));
        _selectedConds.querySelectorAll('.active').classes.remove('active');
        _sendSelectedMovablesUpdate();
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

  void _changeImageDialog(MouseEvent ev) async {
    var result = await upload.display(
      event: ev,
      action: a.GAME_SCENE_UPDATE,
      type: a.IMAGE_TYPE_SCENE,
      extras: {'id': _sceneId},
    );

    if (result != null) {
      if (result is String) {
        await onImgChange(src: result);
      } else {
        await onImgChange(src: result['path']);
        grid.tiles = result['tiles'];
        gridTiles.valueAsNumber = grid.tiles;
      }
    }
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
      )..fromJson(jsons.elementAt(i));

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
    updateRerollableInitiatives();
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
    updateRerollableInitiatives();
    return m;
  }

  void _onMovableCountLimitReached() {
    HtmlNotification('Limit of $movablesPerScene movables reached.').display();
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

  void onMovablesUpdate(json) {
    Iterable changes = json['changes'];
    for (var change in changes) {
      var id = change['movable'];
      var m = movables.firstWhere((m) => m.id == id);
      m.fromJson(change);
    }
  }

  void rescaleMeasurings() {
    var x = grid.tiles;
    var y = x * (grid.size.y / grid.size.x);
    measuringRoot.setAttribute('viewBox', '-0.5 -0.5 $x $y');
  }

  void resetTransform() {
    zoom = -0.5;
    position = Point(0, 0);
  }

  Future<void> onSceneChange(int id) async {
    clear();

    _sceneId = id;
    await onImgChange(updateRef: false);

    mode = PAN;
  }

  void fromJson(int id, Map<String, dynamic> json) async {
    await onSceneChange(id);

    fogOfWar.load(json['fow']);
    grid.fromJson(json['grid']);
    rescaleMeasurings();

    for (var m in json['movables']) {
      onMovableCreate(m);
    }

    initiativeTracker.fromJson(json['initiative']);
    resetTransform();
  }
}

class BoardTransform extends HtmlTransform {
  BoardTransform(Element element, {Point Function() getMaxPosition})
      : super(element, getMaxPosition: getMaxPosition);

  @override
  set zoom(double zoom) {
    super.zoom = zoom;
    var invZoomScale = 'scale(${1 / scaledZoom})';
    querySelectorAll('.distance-text').style.transform = invZoomScale;
  }
}
