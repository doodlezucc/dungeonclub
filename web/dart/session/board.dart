import 'dart:async';
import 'dart:collection';
import 'dart:html';
import 'dart:svg' as svg;

import 'package:dungeonclub/actions.dart' as a;
import 'package:dungeonclub/limits.dart';
import 'package:dungeonclub/point_json.dart';
import 'package:dungeonclub/session_util.dart';
import 'package:grid_space/grid_space.dart';
import 'package:meta/meta.dart';

import '../communication.dart';
import '../font_awesome.dart';
import '../formatting.dart';
import '../html_transform.dart';
import '../lazy_input.dart';
import '../notif.dart';
import '../panels/upload.dart' as upload;
import '../resource.dart';
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
final HtmlElement _selectedLabelWrapper = querySelector('#movableLabel');
final HtmlElement _selectedLabelPrefix = _selectedLabelWrapper.children.first;
final InputElement _selectedLabel = _selectedLabelWrapper.children.last;
final InputElement _selectedSize = querySelector('#movableSize');
final InputElement _selectedAura = querySelector('#movableAura');
final ButtonElement _selectedInvisible = querySelector('#movableInvisible');
final ButtonElement _selectedRemove = querySelector('#movableRemove');
final ButtonElement _selectedSnap = querySelector('#movableSnap');
final HtmlElement _selectedConds = _selectionProperties.querySelector('#conds');

final ButtonElement _fowToggle = querySelector('#fogOfWar');
final ButtonElement _measureToggle = querySelector('#measureDistance');
HtmlElement get _measureSticky => querySelector('#measureSticky');
HtmlElement get _measureVisible => querySelector('#measureVisible');

class Board {
  final Session session;
  final grid = SceneGrid();
  final mapTab = MapTab();
  final movables = <Movable>[];
  final selected = <Movable>{};
  final fogOfWar = FogOfWar();
  final initiativeTracker = InitiativeTracker();
  List<Movable> clipboard = [];

  static const PAN = 'pan';
  static const MEASURE = 'measure';
  static const FOG_OF_WAR = 'fow';

  final showMoveDistances = true;

  BoardTransform _transform;
  BoardTransform get transform => _transform;

  Point get position => transform.position;
  set position(Point p) => transform.position = p;

  double get zoom => transform.zoom;
  set zoom(double zoom) => transform.zoom = zoom;

  double get scaledZoom => transform.scaledZoom;

  int get nextMovableId => movables.getNextAvailableID((e) => e.id);

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
        displayTooltip(fogOfWar.tooltip);
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
      var nicknamePrefix = '';
      if (activeMovable is! EmptyMovable) {
        nicknamePrefix = activeMovable.name;
      }

      _selectedLabelPrefix.text = nicknamePrefix;
      _selectedLabel.value = activeMovable.label;
      _selectedAura.valueAsNumber = activeMovable.auraRadius;
      _updateSelectedInvisible(activeMovable.invisible);
      _selectedSize.valueAsNumber = activeMovable.size;
      _updateSelectionSizeInherit();
      _selectedConds.querySelectorAll('.active').classes.remove('active');
      for (var c = 0; c < Condition.categories.length; c++) {
        final category = Condition.categories[c];
        final row = _selectedConds.children[c].children.first;

        for (var cc = 0; cc < category.conditions.length; cc++) {
          if (activeMovable.conds
              .contains(category.conditions.keys.elementAt(cc))) {
            row.children[cc].classes.add('active');
          }
        }
      }
    }

    _selectionProperties.classes.toggle('hidden', activeMovable == null);
  }

  Scene _refScene;
  Scene get refScene => _refScene;
  bool _init = false;

  Board(this.session) {
    _transform = BoardTransform(this, _e, getMaxPosition: () {
      return Point(
        _ground.naturalWidth,
        _ground.naturalHeight,
      );
    });
    position = Point(0, 0);

    if (!_init) {
      _initBoard();
      _init = true;
    }
  }

  void onPrefabNameChange(Prefab prefab) {
    if (activeMovable?.prefab == prefab) {
      _selectedLabelPrefix.text = prefab.name;
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
          measureMode = int.parse(mMode);
          displayTooltip(getMeasureTooltip());

          // Prevent mode toggle
          if (mode == MEASURE) return;
        } else if (target == _measureSticky) {
          return _toggleMeasureSticky();
        } else if (target == _measureVisible) {
          measureVisible = !measureVisible;
          return;
        }
      }

      mode = MEASURE;
    });
    _fowToggle.onClick.listen((ev) {
      final Element clickedBox = ev.path.firstWhere(
        (e) => e is Element && e.classes.contains('toolbox'),
        orElse: () => null,
      );
      if (clickedBox != null) {
        if (mode == FOG_OF_WAR || clickedBox.previousElementSibling != null) {
          return;
        }
      }
      mode = FOG_OF_WAR;
    });

    _container.onMouseWheel.listen((event) {
      if (event.target is InputElement) {
        if (event.target != document.activeElement) {
          (event.target as InputElement).focus();
        }
      } else {
        if (mode == FOG_OF_WAR && fogOfWar.canvas.activeTool.employMouseWheel) {
          return;
        }

        if (mapTab.visible ||
            event.path
                .any((e) => e is Element && e.classes.contains('controls'))) {
          return;
        }
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

      // Only deselect if no other mouse button is currently pressed
      if (ev.buttons == 0) {
        _deselectAll();
      }
    });

    // Prevent menu bar dropdown on Alt key
    window.onKeyUp.listen((event) {
      if (event.keyCode == 18) event.preventDefault();
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
            // Duplicate with Ctrl+D
            else if (ev.key == 'd') {
              ev.preventDefault();
              cloneMovables(selected);
            }
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
    updateSnapToGrid();
  }

  void applyInactiveSceneWarning() {
    final isActiveScene = refScene.isPlaying;

    initiativeTracker.disabled = !isActiveScene;
    _container
        .querySelector('#inactiveSceneWarning')
        .classes
        .toggle('hidden', isActiveScene);
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

  void _snapSelection() {
    if (mapTab.visible) return;

    for (var m in selected) {
      m.roundToGrid();
    }

    _sendSelectedMovablesSnap();
  }

  void onMovableSnap(Map<String, dynamic> json) {
    for (var jm in json['movables']) {
      var m = movables.firstWhere((mv) => mv.id == jm['id']);
      m.handleSnapEvent(jm);
    }
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

  /// Sends the current position and angle of all selected movables.
  void _sendSelectedMovablesSnap() {
    Map convertToJson(Movable m) => {
          'id': m.id,
          ...writePoint(m.position),
          'angle': m.angle,
        };

    socket.sendAction(a.GAME_MOVABLE_SNAP, {
      'movables': selected.map(convertToJson).toList(),
    });
  }

  void _updateSelectedInvisible(bool v) {
    _selectedInvisible.classes.toggle('active', v);
    _selectedInvisible.querySelector('span').text = v ? 'Invisible' : 'Visible';
    _selectedInvisible.querySelector('i').className =
        'fas fa-' + (v ? 'eye-slash' : 'eye');
  }

  void updateSnapToGrid() {
    final allSnapped = selected.every((m) {
      final p =
          grid.grid.gridSnapCentered(m.position, m.displaySize).snapDeviation();
      return p == m.position;
    });
    _selectedSnap.disabled = allSnapped;
  }

  void _initSelectionHandler() {
    _selectedRemove.onClick.listen((_) => _removeSelectedMovables());
    _selectedSnap.onClick.listen((_) => _snapSelection());

    _listenSelectedLazyUpdate(_selectedLabel, onChange: (m, value) {
      m.label = value;
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
      m.setSizeWithGridSpecifics(int.parse(value));
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
    SimpleEvent lastEv;
    StreamController<SimpleEvent> moveStreamCtrl;
    Timer pingTimer;
    Point startP;
    Point previous;
    final lastZooms = Queue<double>();
    final lastPoints = Queue<Point>();
    int initialButton;
    double pinchStart;
    double pinchZoomStart;
    bool pan;

    void _alignAngleArrow() {
      if (activeMovable == null) return;

      var display = false;

      if (lastEv != null && lastEv.alt) {
        // Only show angle arrow if no movable is hovered
        display = !lastEv.path.any(
          (e) => e is Element && e.classes.contains('movable'),
        );
      }

      if (display) {
        angleArrow.align(this, lastEv.p * (1 / scaledZoom));
      }
      angleArrow.visible = display;
    }

    double pinchDistance(Iterable<Touch> touches) {
      return touches.first.page.distanceTo(touches.last.page);
    }

    Point center(Iterable<Touch> touches) {
      var counted = touches;
      if (!(pan ?? true)) counted = touches.take(1);

      return counted.fold(Point<num>(0, 0), (p, t) => p + t.page) *
          (1 / counted.length);
    }

    Point offCenter(Point p) {
      var center = Point<num>(window.innerWidth, window.innerHeight) * 0.5;
      return p - center;
    }

    void listenToCursorEvents<T extends Event>(
      Point Function(T ev) evToPoint,
      Stream<T> startEvent,
      Stream<T> moveEvent,
      Stream<T> endEvent,
    ) {
      SimpleEvent toSimple(T ev) {
        final evP = evToPoint(ev);
        final delta = evP - (previous ?? evP);
        previous = evP;
        final p = previous - _e.getBoundingClientRect().topLeft;
        return SimpleEvent.fromJS(ev, p, delta);
      }

      startEvent.listen((ev) async {
        startP = evToPoint(ev);
        previous = startP;

        if (ev is TouchEvent && ev.touches.length > 1) {
          pinchStart = pinchDistance(ev.touches);
          pinchZoomStart = scaledZoom;
          return pingTimer?.cancel();
        }

        lastZooms.clear();
        lastPoints.clear();

        var start = toSimple(ev);
        lastEv = start;

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

        if (mode == FOG_OF_WAR &&
            start.button == 2 &&
            fogOfWar.canvas.activePath != null) {
          return fogOfWar.canvas.instantiateActivePolygon();
        }

        initialButton = start.button;

        // Start ping timer
        if (mode == PAN && initialButton == 0 && !angleArrow.visible) {
          final isBoardDrag = ev.path.contains(_e);
          if (isBoardDrag) {
            pingTimer = Timer(Duration(milliseconds: 300), () {
              var pos = start.p * (1 / scaledZoom);

              socket.sendAction(a.GAME_PING, {
                ...writePoint(pos),
                'player': session.charId,
              });
              displayPing(pos, session.charId);
            });
          }
        }

        moveStreamCtrl = StreamController();
        var stream = moveStreamCtrl.stream;

        pan = !(start.button == 0 && mode != PAN);

        Movable clickedMovable;

        if (start.button == 0) {
          if (mode == MEASURE) {
            _handleMeasuring(start, stream, measureMode);
          } else if (mode == PAN) {
            if (start.ctrl) {
              _handleSelectArea(start, stream);
              pan = false;
            } else {
              // Figure out clicked token
              var movableElem = ev.path.firstWhere(
                (e) =>
                    e is Element &&
                    e.classes.contains('movable') &&
                    e.classes.contains('accessible'),
                orElse: () => null,
              );

              if (movableElem != null) {
                // Move clicked/selected token(s)
                for (var mv in movables) {
                  if (mv.e == movableElem) {
                    clickedMovable = mv;
                    break;
                  }
                }
                _handleMovableMove(start, stream, clickedMovable);
                pan = false;
              } else if (start.alt && activeMovable != null) {
                // Change token angle
                _handleMovableRotate(start, stream);
                pan = false;
              } else if (selectedPrefab != null) {
                // Create new token at cursor position
                final worldPos = grid.centeredWorldPoint(
                  start.p * (1 / scaledZoom),
                  selectedPrefab.size,
                );
                var gridPos = grid.grid.worldToGridSpace(worldPos);

                var newMov =
                    await addMovable(selectedPrefab, gridPos.undeviate());

                if (newMov != null) {
                  toggleSelect([newMov], state: true);
                  pan = false;
                  if (newMov is EmptyMovable) {
                    // Focus label input of created labeled token
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

        await endEvent.firstWhere((ev) {
          if (ev is TouchEvent) {
            previous = evToPoint(ev);
            return ev.touches.isEmpty;
          }
          return toSimple(ev).button == initialButton;
        });

        var isClickEvent = false;
        if (pingTimer != null && pingTimer.isActive) {
          pingTimer.cancel();
          isClickEvent = true;
        } else if (pan) {
          // Apply average velocity from last few pinches
          if (lastZooms.isNotEmpty) {
            var zoomVel = lastZooms.fold(0.0, (v, z) => v + z);
            transform.applyZoomForce(zoomVel / lastZooms.length);
          }
          if (lastPoints.isNotEmpty) {
            var velocity = lastPoints.fold(Point<num>(0, 0), (p, q) => p += q);
            transform.applyForce(velocity * (1 / lastPoints.length));
          }
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
        final sev = toSimple(ev);
        lastEv = sev;
        if (moveStreamCtrl != null) {
          var point = evToPoint(ev);
          if (pingTimer != null && pingTimer.isActive) {
            if (ev is! TouchEvent || point.squaredDistanceTo(startP) > 64) {
              pingTimer.cancel();
            }
          }

          moveStreamCtrl.add(sev);

          if (ev is TouchEvent && pan) {
            if (ev.touches.length == 1) {
              // Pinch zooming
              lastPoints.add(sev.movement);
            } else {
              // Pinch zooming
              var distance = pinchDistance(ev.touches);
              var offset = offCenter(point);
              var off1 = offset * (1 / scaledZoom);
              var nZoom = pinchZoomStart * (distance / pinchStart);
              var deltaZoom = nZoom - scaledZoom;
              transform.scaledZoom = nZoom;
              lastZooms.add(deltaZoom);
              var off2 = offset * (1 / scaledZoom);
              var delta = off2 - off1;
              position += delta;
            }
            if (lastZooms.length > 5) lastZooms.removeFirst();
            if (lastPoints.length > 5) lastPoints.removeFirst();
          }
        } else {
          if (selectedPrefab != null) {
            var p = evToPoint(ev) - _e.getBoundingClientRect().topLeft;
            alignMovableGhost(p * (1 / scaledZoom), selectedPrefab);
            toggleMovableGhostVisible(true);
          } else {
            _alignAngleArrow();
          }
        }
      });
    }

    listenToCursorEvents<MouseEvent>((ev) => ev.page, _container.onMouseDown,
        window.onMouseMove, window.onMouseUp);

    listenToCursorEvents<TouchEvent>((ev) => center(ev.touches),
        _container.onTouchStart, window.onTouchMove, window.onTouchEnd);

    void triggerUpdate(bool alt) {
      if (lastEv != null) {
        lastEv.alt = alt;
        _alignAngleArrow();

        if (moveStreamCtrl != null) {
          moveStreamCtrl.add(lastEv);
        }
      }
    }

    window.onKeyDown
        .where((ev) => !ev.repeat && ev.keyCode == 18)
        .listen((ev) => triggerUpdate(true));
    window.onKeyUp
        .where((ev) => ev.keyCode == 18)
        .listen((_) => triggerUpdate(false));
  }

  void _handleMovableRotate(SimpleEvent first, Stream<SimpleEvent> moveStream) {
    var hasChanged = false;
    void onMove(SimpleEvent ev) {
      final point = ev.p;
      angleArrow.align(this, point * (1 / scaledZoom), updateSourceAngle: true);
      final degrees = angleArrow.angle;

      for (var mv in selected) {
        if (mv.angle != degrees) {
          mv.angle = degrees;
          hasChanged = true;
        }
      }
    }

    onMove(first);

    moveStream.listen(onMove, onDone: () {
      if (hasChanged) {
        _sendSelectedMovablesSnap();
      }
    });
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
    Point scale(Point p) =>
        grid.offsetToGridSpaceUnscaled(p, offset: const Point(0, 0));

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
      SimpleEvent first, Stream<SimpleEvent> moveStream, Movable clicked) {
    toggleMovableGhostVisible(false);
    var affected = {clicked, ...selected};
    final origins = {for (var mv in affected) mv: mv.position};

    var movedOnce = false;
    var lastDelta = Point<double>(0, 0);
    MeasuringPath measuring;

    void setCssTransitionEnabled(bool enable) {
      for (var mv in affected) {
        mv.e.classes.toggle('no-animate-move', !enable);
      }
    }

    void alignText() {
      var mPos = clicked.position;
      var offset = clicked.displaySizePoint.cast<double>() * 0.35;
      var textPos = grid.grid.gridToWorldSpace(mPos + offset);
      measuring.alignDistanceText(textPos);
    }

    Point<double> zoomApplied(Point p) {
      return scalePoint(p, (v) => v / scaledZoom);
    }

    Point<double> worldSnapCentered(Point<double> worldPoint) {
      return grid.grid
          .worldSnapCentered(worldPoint, clicked.displaySize)
          .cast<double>();
    }

    final gridOrigin = clicked.position;

    moveStream.listen((ev) {
      if (!movedOnce) {
        movedOnce = true;
        if (!clicked.e.classes.contains('selected') && !first.shift) {
          _deselectAll();
          affected = {clicked};
        }

        var showDistance = affected.length == 1;
        if (showDistance) {
          measuring = MeasuringPath(clicked.position, -1,
              background: true, size: clicked.displaySize);
          transform.applyInvZoom();
          alignText();
          imitateMovableGhost(clicked);
        }

        setCssTransitionEnabled(false);
      }

      var worldPoint = zoomApplied(ev.p);
      if (!ev.alt) {
        worldPoint = worldSnapCentered(worldPoint);
      }

      final gridCursor = grid.grid.worldToGridSpace(worldPoint);
      var delta = gridCursor - gridOrigin;
      delta = delta.undeviate();

      if (ev.isMouseDown && ev.button == 2 && measuring != null) {
        measuring.handleRightclick(gridCursor, doSnap: false);
      }

      if (delta != lastDelta) {
        for (var mv in affected) {
          mv.position = origins[mv] + delta;
        }
        lastDelta = delta;
        if (measuring != null) {
          measuring.handleMove(clicked.position, doSnap: false);
          alignText();
          toggleMovableGhostVisible(delta != Point(0, 0), translucent: true);
        }
      }
    }, onDone: () {
      setCssTransitionEnabled(true);
      toggleMovableGhostVisible(false);
      measuring?.dispose();
      if (lastDelta != Point(0, 0)) {
        return socket.sendAction(a.GAME_MOVABLE_MOVE, {
          'movables': affected.map((e) => e.id).toList(),
          ...writePoint(lastDelta)
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

    final snapSize = doOffset ? 1 : 0;

    Point worldToGrid(Point p) {
      return grid.grid.worldToGridSpace(p).snapDeviation().cast<num>();
    }

    Point snapWorldToGrid(Point p) {
      var gridPos = worldToGrid(p);
      return grid.grid.gridSnapCentered(gridPos, snapSize).snapDeviation();
    }

    var origin = snapWorldToGrid(p);

    removeMeasuring(session.charId, sendEvent: true);
    var m = Measuring.create(type, origin, session.charId);
    m.alignDistanceText(p);
    transform.applyInvZoom();

    if (isPublic) sendCreationEvent(type, origin, p);

    Point measureEnd;
    var hasChanged = false;

    // ~30 FPS transmission
    var syncTimer = Timer.periodic(Duration(milliseconds: 33), (_) {
      if (hasChanged) {
        hasChanged = false;

        measureEnd = worldToGrid(p);

        m.handleMove(measureEnd);
        m.alignDistanceText(p);

        if (isPublic) {
          m.sendUpdateEvent(measureEnd);
        }
      }
    });

    var keySub = window.onKeyDown.listen((ev) {
      if (ev.keyCode == 32) {
        m.handleRightclick(measureEnd); // Trigger with spacebar
      }
    });

    moveStream.listen((ev) {
      p = ev.p * (1 / scaledZoom);

      if (ev.button == 2) {
        m.handleRightclick(measureEnd);
      } else if (ev.button == 1) {
        _measureSticky.classes.toggle('active');
      }

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
    final categories = Condition.categories;
    for (var category in categories) {
      final row = DivElement()..className = 'toolbox';
      final div = DivElement()
        ..append(row)
        ..append(ParagraphElement()..text = category.name);

      for (var e in category.conditions.entries) {
        final id = e.key;
        final cond = e.value;
        final ico = icon(cond.icon)..append(SpanElement()..text = cond.name);

        row.append(ico
          ..onClick.listen((_) {
            var activate = !_activeMovable.conds.contains(id);
            selected.forEach((m) => m.toggleCondition(id, activate));
            ico.classes.toggle('active', activate);
            _sendSelectedMovablesUpdate();
          }));
      }

      _selectedConds.append(div);
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
    _container.querySelector('#tooltip').innerHtml = formatToHtml(text);
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
    final result = await upload.display(
      event: ev,
      action: a.GAME_SCENE_UPDATE,
      type: a.IMAGE_TYPE_SCENE,
      extras: {'id': refScene.id},
    );

    if (result == null) return; // Upload was cancelled

    final path = result['image'];
    final tiles = result['tiles'];

    await changeSceneImage(path);
    if (tiles != null) {
      grid.tiles = tiles;
      gridTiles.valueAsNumber = tiles;
    }
  }

  Future<void> changeSceneImage(String path) async {
    refScene.background.path = path;
    refScene.applyBackground();

    final src = Resource(path).url;
    await _applyImage(src);
  }

  Future<void> _applyImage(String src) async {
    _ground.src = src;

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

    if (session.isDemo) {
      result = List<int>.generate(source.length, (i) => nextMovableId + i);
    } else if (result == null) {
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

      m.label = generateNewLabel(m, movables);

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

    if (session.isDemo) {
      id = nextMovableId;
    } else if (id == null) {
      _onMovableCountLimitReached();
      return null;
    }

    var m = Movable.create(
        board: this, prefab: prefab, id: id, pos: pos, conds: []);

    m.label = generateNewLabel(m, movables);

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
    )..fromJson(json);
    movables.add(m);
    grid.e.append(m.e);
  }

  void onUpdatePrefabImage(Prefab p) {
    for (var movable in movables) {
      if (movable.prefab == p) {
        movable.applyImage();
      }
    }

    initiativeTracker.onUpdatePrefabImage(p);
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
      _movableEvent(json, (m) => m.onMove(parsePoint<double>(json)));

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
    fogOfWar.applyUseGrid(this);
  }

  void resetTransform() {
    zoom = -0.5;
    position = Point(0, 0);
  }

  Future<void> _onSceneChange() async {
    clear();

    await _applyImage(refScene.background.url);
    mode = PAN;
  }

  void fromJson(Map<String, dynamic> json) async {
    final int sceneID = json['id'];
    _refScene = session.scenes.find((e) => e.id == sceneID);
    session.applySceneEditPlayStates();

    await _onSceneChange();

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
  final Board board;
  final Map<Element, bool> _invZoom = {};

  BoardTransform(this.board, Element element, {Point Function() getMaxPosition})
      : super(element, getMaxPosition: getMaxPosition);

  @override
  set zoom(double zoom) {
    super.zoom = zoom;
    applyInvZoom();
  }

  String get _invZoomScale => 'scale(${1 / scaledZoom})';
  String get _invZoomScaleCell =>
      'scale(${70 / board.grid.cellWidth / scaledZoom})';

  void applyInvZoom() {
    final scale = _invZoomScale;
    final scaleCell = _invZoomScaleCell;
    _invZoom.forEach((e, c) => e.style.transform = c ? scaleCell : scale);
  }

  Element registerInvZoom(Element e, {bool scaleByCell = false}) {
    _invZoom[e] = scaleByCell;
    e.style.transform = scaleByCell ? _invZoomScaleCell : _invZoomScale;
    return e;
  }

  void unregisterInvZoom(Element e) {
    _invZoom.remove(e);
  }
}
