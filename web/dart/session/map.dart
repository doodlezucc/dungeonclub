import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'dart:math';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:dungeonclub/actions.dart';
import 'package:dungeonclub/iterable_extension.dart';
import 'package:dungeonclub/session_util.dart';
import 'package:web_whiteboard/whiteboard.dart';

import '../../main.dart';
import '../communication.dart';
import '../html_helpers.dart';
import '../html_transform.dart';
import '../panels/upload.dart' as uploader;
import '../resource.dart';
import 'map_tool_info.dart';

final HtmlElement _e = queryDom('#map');
final HtmlElement _mapContainer = _e.queryDom('#maps');
final HtmlElement _minimapContainer = _e.queryDom('#mapSelect');
final ButtonElement _backButton = _e.queryDom('button[type=reset]');
final ButtonElement _imgButton = _e.queryDom('#addMap');
final InputElement _name = _e.queryDom('#mapName');
final ButtonElement _shared = _e.queryDom('#mapShared');
final HtmlElement _tools = _e.queryDom('#mapTools');
final HtmlElement _toolInfo = _e.queryDom('#toolInfo');
final InputElement _color = _e.queryDom('#activeColor');

final HtmlElement _indexText = _e.queryDom('#mapIndex');
final _navLeft = _name.previousElementSibling as ButtonElement;
final _navRight = _name.parent!.children.last as ButtonElement;

ButtonElement get _deleteButton => _e.queryDom('#mapDelete');

class MapTab {
  final maps = <GameMap>[];

  bool get editMode => _e.classes.contains('edit');
  set editMode(bool editMode) {
    _e.classes.toggle('edit', editMode);
    _backButton.childNodes[0].text = editMode ? 'Overview' : 'Exit Map View';

    if (!editMode) {
      map!.transform.reset();
    }

    Future.delayed(
      Duration(milliseconds: editMode ? 400 : 0),
      () => _mapContainer.classes.toggle('animate', editMode),
    );
  }

  int _mapIndex = 0;
  int get mapIndex => _mapIndex;
  set mapIndex(int mapIndex) {
    if (map != null) {
      map!.whiteboard.captureInput = false;
      map!.transform.reset();
    }

    _mapIndex = mapIndex;

    final focusedMap = map!;

    _mapContainer.style.left = '${mapIndex * -100}%';
    _name.value = focusedMap.name;
    shared = focusedMap.shared;
    mode = mode;
    _updateHistoryButtons();
    _updateNavigateButtons();
    _updateIndexText();
    Future.microtask(() => focusedMap._fixScaling());
  }

  Point get mapSize {
    if (map == null) return Point(0, 0);

    var img = map!.whiteboard.backgroundImageElement;
    return Point(img.naturalWidth, img.naturalHeight);
  }

  GameMap? get map =>
      (maps.isNotEmpty && mapIndex < maps.length) ? maps[mapIndex] : null;

  String _mode = 'draw';
  String get mode => _mode;
  set mode(String mode) {
    _mode = mode;
    _tools.querySelectorAll('.active:not(#mapShared)').classes.remove('active');
    _tools.queryDom('[mode=$mode]').classes.add('active');
    _setToolInfo(mode);

    _color.disabled = mode != 'draw';

    if (maps.isNotEmpty) {
      var wb = map!.whiteboard;
      if (mode == 'erase') {
        wb.mode = Whiteboard.modeDraw;
        wb.eraser = true;
      } else {
        wb.mode = mode;
        wb.eraser = false;

        if (mode == 'draw') {
          wb.activeColor = _color.value!;
        }
      }
    }
  }

  bool get visible => _e.classes.contains('show');
  set visible(bool visible) {
    _e.classes.toggle('show', visible);
    if (visible) {
      _updateNavigateButtons();
    }
  }

  set shared(bool shared) {
    _shared.classes.toggle('active', shared);
    _updateToolsVisibility();
  }

  void _updateToolsVisibility() {
    final currentMap = map!;

    final useTools = (user.session!.isDM || currentMap.shared) &&
        !currentMap.transform.isOffCenter;

    currentMap.whiteboard.captureInput = useTools;
    _tools.classes.toggle('hidden', !useTools);
  }

  void _updateNavigateButtons() {
    _navLeft.disabled = mapIndex == 0;

    if (user.session!.isDM) {
      var showAdd = mapIndex == maps.length - 1;
      var icon = showAdd ? 'plus' : 'chevron-right';
      _navRight.classes.toggle('add-map', showAdd);
      _navRight.children.first.className = 'fas fa-$icon';

      if (showAdd && maps.length >= user.mapsPerCampaign) {
        _navRight.disabled = true;
        _navRight.queryDom('span').text =
            'Limit of ${user.mapsPerCampaign} Maps Reached!';
      } else {
        _navRight.disabled = maps.isEmpty;
        _navRight.queryDom('span').text = 'Create New Map';
      }
    } else {
      _navRight.disabled = mapIndex >= maps.length - 1;
    }
  }

  ButtonElement _toolBtn(String name) => _tools.queryDom('[action=$name]');

  void _updateHistoryButtons() {
    _toolBtn('clear').disabled = map!.whiteboard.isClear;
    _toolBtn('undo').disabled = map!.whiteboard.history.positionInStack == 0;
    _toolBtn('redo').disabled = !map!.whiteboard.history.canRedo;
  }

  void _setToolInfo(String id) {
    try {
      final info = getToolInfo(id, user.session!.isDM);
      _toolInfo.innerHtml = info;
    } on ArgumentError catch (_) {}
  }

  Future<bool> _uploadNewMap(MouseEvent ev) async {
    if (maps.length >= user.mapsPerCampaign) return false;

    final response = await uploader.display(
      event: ev,
      action: GAME_MAP_CREATE,
      type: IMAGE_TYPE_MAP,
    );

    if (response != null) {
      // Fallback to next available ID in demo session
      final mapID = response['map'] ?? maps.getNextAvailableID((e) => e.id);

      addMap(mapID, '', response['image'], false);
      _enterEdit(mapID);
      _name.focus();
      return true;
    }
    return false;
  }

  void _back() {
    if (editMode) {
      editMode = false;
    } else {
      visible = false;
    }
  }

  void initMapControls() {
    _backButton.onClick.listen((_) => _back());

    window.onResize.listen((_) => maps.forEach((m) => m._fixScaling()));
    window.onKeyDown.listen((ev) {
      if (!visible ||
          ev.target is InputElement ||
          ev.target is TextAreaElement) {
        return;
      }

      if (ev.keyCode == 27) {
        ev.preventDefault();
        _back();
        // Arrow key controls
      } else if (editMode) {
        if (ev.keyCode == 37 && mapIndex > 0) {
          mapIndex--;
        } else if (ev.keyCode == 39 && mapIndex < maps.length - 1) {
          mapIndex++;
        }
      }
    });

    _navLeft.onLMB.listen((_) => mapIndex--);
    _navRight.onLMB.listen((ev) async {
      if (user.session!.isDM && mapIndex == maps.length - 1) {
        await _uploadNewMap(ev);
      } else {
        mapIndex++;
      }
    });

    _imgButton.onLMB.listen(_uploadNewMap);
    _deleteButton.onClick.listen((_) => _deleteCurrentMap());

    _initZoom();
    _initTools();
    _initMapName();
    _shared.onClick.listen((_) {
      final currentMap = map!;

      currentMap.shared = !currentMap.shared;
      shared = currentMap.shared;
      socket.sendAction(GAME_MAP_UPDATE, {
        'map': currentMap.id,
        'shared': currentMap.shared,
      });
    });
  }

  void _initZoom() {
    StreamController<SimpleEvent>? moveStreamCtrl;
    Point? previous;
    int? initialButton;

    _e.onMouseWheel.listen((ev) {
      if (map != null) {
        if (visible && editMode && map!.whiteboard.selectedText == null) {
          map!.transform.handleMousewheel(ev);
        }
      }
    });

    void listenToCursorEvents<T extends Event>(
      Point Function(T ev) evToPoint,
      Stream<T> startEvent,
      Stream<T> moveEvent,
      Stream<T> endEvent,
    ) {
      SimpleEvent toSimple(T ev) {
        final point = evToPoint(ev);
        final delta = point - previous!;
        previous = point;

        return SimpleEvent.fromJS(ev, point, delta);
      }

      startEvent.listen((ev) async {
        final focusedMap = map;

        if (focusedMap == null) {
          return;
        }

        previous = evToPoint(ev);
        var start = toSimple(ev);

        if (start.button == 0 && !focusedMap.transform.isOffCenter) return;

        ev.preventDefault();
        document.activeElement?.blur();

        if (start.button != initialButton && moveStreamCtrl != null) return;

        initialButton = start.button;
        moveStreamCtrl = StreamController();
        var stream = moveStreamCtrl!.stream;

        if (start.ctrl && initialButton == 1) {
          focusedMap.transform.handleFineZooming(start, stream);
        } else {
          focusedMap.transform.handlePanning(start, stream);
        }

        await endEvent.firstWhere((ev) => toSimple(ev).button == initialButton);

        final streamCopy = moveStreamCtrl!;
        moveStreamCtrl = null;
        await streamCopy.close();
      });

      moveEvent.listen((ev) {
        if (moveStreamCtrl != null) {
          moveStreamCtrl!.add(toSimple(ev));
        }
      });
    }

    listenToCursorEvents<MouseEvent>(
        (ev) => ev.page, _e.onMouseDown, window.onMouseMove, window.onMouseUp);

    listenToCursorEvents<TouchEvent>((ev) => ev.targetTouches![0].page,
        _e.onTouchStart, window.onTouchMove, window.onTouchEnd);
  }

  void _initTools() {
    void registerAction(String name, void Function(MouseEvent ev) action) {
      ButtonElement button = _tools.queryDom('[action=$name]')
        ..onClick.listen(action);

      button.onMouseEnter.listen((_) => _setToolInfo(name));
      button.onMouseLeave.listen((_) => _setToolInfo(mode));
    }

    void clearMap() {
      map?.whiteboard.clear();
      _toolBtn('clear').disabled = true;
    }

    _color.onInput.listen((_) {
      if (maps.isNotEmpty) {
        map!.whiteboard.activeColor = _color.value!;
      }
    });

    _tools.children[0].children.forEach((element) {
      if (element is ButtonElement) {
        element.onClick.listen((_) {
          mode = element.attributes['mode']!;
        });
      }
    });

    registerAction('undo', (_) => map?.whiteboard.history.undo());
    registerAction('redo', (_) => map?.whiteboard.history.redo());
    registerAction('clear', (_) => clearMap());
    registerAction('change', (ev) async {
      final currentMap = map!;

      final response = await uploader.display(
        event: ev,
        action: GAME_MAP_UPDATE,
        type: IMAGE_TYPE_MAP,
        extras: {'map': currentMap.id},
      );

      if (response != null) {
        clearMap();
        currentMap.image.path = response['image'];
        currentMap.applyImage();
      }
    });

    _toolInfo.onClick.listen((_) => _setInfoVisible(false));
    _e.queryDom('#infoShow').onClick.listen((_) => _setInfoVisible(true));
    _tools.classes
        .toggle('collapsed', window.localStorage['mapToolInfo'] == 'false');
  }

  void _setInfoVisible(bool v) {
    _tools.classes.toggle('collapsed', !v);
    window.localStorage['mapToolInfo'] = '$v';
  }

  void _listenToEraseAcross() {
    window.onKeyDown.listen((ev) {
      if (ev.keyCode == 16) map?.whiteboard.eraseAcrossLayers = true;
    });
    window.onKeyUp.listen((ev) {
      if (ev.keyCode == 16) map?.whiteboard.eraseAcrossLayers = false;
    });
  }

  void _deleteCurrentMap() {
    socket.sendAction(GAME_MAP_REMOVE, {'map': map!.id});
    onMapRemove(map!.id);
  }

  void onMapRemove(int id) {
    final map = maps.find((m) => m.id == id)!;

    map._dispose();
    maps.remove(map);

    if (maps.isEmpty) {
      _onAllRemoved();
    } else {
      mapIndex = min(max(mapIndex, 0), maps.length - 1);
    }
  }

  void _initMapName() {
    final parent = _name.parent!;
    ButtonElement confirmBtn = parent.queryDom('.dm');
    var nameConfirm = StreamGroup.merge(<Stream>[
      _name.onKeyDown.where((ev) => ev.keyCode == 13),
      confirmBtn.onMouseDown,
    ]);

    var focus = false;
    _name.onFocus.listen((_) {
      focus = true;
      parent.classes.add('focus');
    });
    _name.onBlur.listen((_) async {
      await Future.delayed(Duration(milliseconds: 50));
      if (focus) {
        _name.value = map!.name;
        parent.classes.remove('focus');
        focus = false;
      }
    });

    nameConfirm.listen((_) {
      if (focus) {
        focus = false;
        parent.classes.remove('focus');
        _name.blur();
        map!.name = _name.value!;
        socket
            .sendAction(GAME_MAP_UPDATE, {'map': map!.id, 'name': _name.value});
      }
    });
  }

  void _onFirstUpload() {
    mapIndex = 0;
    if (user.session!.isDM) {
      _name.disabled = false;
    }
  }

  void _onAllRemoved() {
    editMode = false;
    _updateNavigateButtons();
    _name.value = '';
    if (user.session!.isDM) {
      _name.disabled = true;
    }
  }

  void fromJson(Iterable json) {
    maps.removeWhere((m) {
      m._em.remove();
      return true;
    });

    json.forEach((jMap) => addMap(jMap['map'], jMap['name'], jMap['image'],
        jMap['shared'], jMap['data']));
    if (maps.isNotEmpty) {
      _onFirstUpload();
    }

    if (user.session!.isDM) {
      _color.value = '#000000';
    } else {
      _color.value = user.session!.getPlayerColor(user.session!.charId);
    }
    mode = Whiteboard.modeDraw;

    if (user.session!.isDM) {
      _listenToEraseAcross();
    }
  }

  void _updateIndexText() => _indexText.text = '${mapIndex + 1}/${maps.length}';

  void addMap(int id, String name, String image, bool shared,
      [String? encodedData]) {
    final map = GameMap(
      this,
      id,
      name: name,
      shared: shared,
      encodedData: encodedData,
      onEnterEdit: () => _enterEdit(id),
      image: Resource(image),
    );
    map.whiteboard.history.onChange.listen((_) => _updateHistoryButtons());
    maps.add(map);

    if (maps.length == 1) _onFirstUpload();

    _updateNavigateButtons();
    _updateIndexText();
  }

  void _enterEdit(int id) {
    mapIndex = maps.indexWhere((m) => m.id == id);
    editMode = true;
  }

  void onMapUpdate(Map<String, dynamic> json) {
    var map = maps.firstWhere((m) => m.id == json['map']);
    var name = json['name'];
    var shared = json['shared'];
    if (name != null) {
      map.name = name;
      if (maps[mapIndex] == map) _name.value = map.name;
    } else if (shared != null) {
      map.shared = shared;
      if (maps[mapIndex] == map) this.shared = shared;
    } else {
      map.image.path = json['image'];
      map.applyImage();
    }
  }

  void handleEvent(Uint8List bytes) {
    var map = maps.firstWhere((m) => m.id == bytes.first);

    map.whiteboard.socket.handleEventBytes(bytes.sublist(1));
    map.updateMiniImage();
  }
}

class GameMap {
  final MapTab mapTab;

  final int id;
  final Resource image;
  late MapTransform transform;
  late HtmlElement _em;
  late HtmlElement _container;
  late HtmlElement _minimap;
  late SpanElement _miniTitle;
  late Whiteboard whiteboard;
  bool shared;

  String get name => _miniTitle.text!;
  set name(String name) {
    _miniTitle.text = name;
  }

  GameMap(
    this.mapTab,
    this.id, {
    String name = '',
    this.shared = false,
    String? encodedData,
    required this.image,
    required void Function() onEnterEdit,
  }) {
    _em = DivElement()
      ..className = 'map'
      ..append(_container = DivElement());
    _mapContainer.append(_em);

    _minimap = DivElement()
      ..className = 'minimap'
      ..append(_miniTitle = SpanElement())
      ..onClick.listen((_) => onEnterEdit());
    _minimapContainer.insertBefore(_minimap, _imgButton);
    this.name = name;

    whiteboard = Whiteboard(_container, textControlsWrapMin: 150)
      ..backgroundImageElement.crossOrigin = 'anonymous'
      ..socket.sendStream.listen((data) {
        updateMiniImage();
        socket.send(Uint8List.fromList([id, ...data]).buffer);
      })
      ..useStartEvent = (ev) {
        if (isMobile) return false;
        return ev is! MouseEvent || ev.button == 0;
      };

    if (encodedData != null) {
      whiteboard.fromBytes(base64.decode(encodedData));
    } else {
      for (var i = 0; i <= user.session!.characters.length; i++) {
        whiteboard.addDrawingLayer();
      }
    }

    // Assign user their own exclusive drawing layer
    if (user.session!.isDM) {
      whiteboard.layerIndex = 0;
    } else {
      final myChar = user.session!.myCharacter!;
      final pcIndex = user.session!.characters.indexOf(myChar);

      whiteboard.layerIndex = 1 + pcIndex;
    }
    applyImage();

    transform = new MapTransform(this);
  }

  void _dispose() {
    _em.remove();
    _minimap.remove();
    whiteboard.history.erase();
    whiteboard.captureInput = false;
  }

  void _fixScaling() {
    _container.style.width = '100%';
    whiteboard.updateScaling();
    var img = _container.queryDom('image');

    var bestWidth = img.getBoundingClientRect().width;
    if (bestWidth > 0) {
      _container.style.width = '${bestWidth}px';
      whiteboard.updateScaling();
    }
  }

  Future<void> updateMiniImage() async {
    var divide = whiteboard.naturalWidth / 300;
    var canvas = CanvasElement(
      width: whiteboard.naturalWidth ~/ divide,
      height: whiteboard.naturalHeight ~/ divide,
    );
    canvas.context2D.scale(1 / divide, 1 / divide);
    whiteboard.drawToCanvas(canvas);
    var base64 = await uploader.canvasToBase64(canvas, includeHeader: true);
    _minimap.style.backgroundImage = "url('$base64')";
  }

  void applyImage() async {
    final src = image.url;

    await whiteboard.changeBackground(src);
    await updateMiniImage();

    // Different browsers need different times to be able to call _fixScaling
    for (var i = 0; i < 5; i++) {
      await Future.delayed(Duration(milliseconds: 20), _fixScaling);
    }
  }
}

class MapTransform extends HtmlTransform {
  final GameMap map;
  bool isOffCenter = false;
  Point Function()? getMapSize;

  MapTransform(this.map) : super(map._em, zoomAmount: 0.2) {
    getMaxPosition = () => map.mapTab.mapSize * zoom;
  }

  void _setOffCenter(bool v) {
    if (isOffCenter != v) {
      isOffCenter = v;
      map.mapTab._updateToolsVisibility();
    }
  }

  @override
  set zoom(double zoom) {
    super.zoom = min(max(zoom, 0), 0.85);
    clampPosition();
    _setOffCenter(super.zoom != 0);
  }
}
