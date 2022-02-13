import 'dart:convert';
import 'dart:html';
import 'dart:math';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:dnd_interactive/actions.dart';
import 'package:dnd_interactive/limits.dart';
import 'package:web_whiteboard/whiteboard.dart';

import '../../main.dart';
import '../communication.dart';
import '../panels/upload.dart' as uploader;
import 'map_tool_info.dart';

final HtmlElement _e = querySelector('#map');
final HtmlElement _mapContainer = _e.querySelector('#maps');
final HtmlElement _minimapContainer = _e.querySelector('#mapSelect');
final ButtonElement _backButton = _e.querySelector('button[type=reset]');
final ButtonElement _imgButton = _e.querySelector('#addMap');
final InputElement _name = _e.querySelector('#mapName');
final ButtonElement _shared = _e.querySelector('#mapShared');
final HtmlElement _tools = _e.querySelector('#mapTools');
final HtmlElement _toolInfo = _e.querySelector('#toolInfo');
final InputElement _color = _e.querySelector('#activeColor');

final HtmlElement _indexText = _e.querySelector('#mapIndex');
final ButtonElement _navLeft = _name.previousElementSibling;
final ButtonElement _navRight = _name.parent.children.last;

ButtonElement get _deleteButton => _e.querySelector('#mapDelete');

class MapTab {
  final maps = <GameMap>[];

  bool get editMode => _e.classes.contains('edit');
  set editMode(bool editMode) {
    _e.classes.toggle('edit', editMode);
    _backButton.childNodes[0].text = editMode ? 'Overview' : 'Exit Map View';

    Future.delayed(
      Duration(milliseconds: editMode ? 400 : 0),
      () => _mapContainer.classes.toggle('animate', editMode),
    );
  }

  int _mapIndex = 0;
  int get mapIndex => _mapIndex;
  set mapIndex(int currentMap) {
    _mapIndex = currentMap;
    _mapContainer.style.left = '${currentMap * -100}%';
    _name.value = map.name;
    shared = map.shared;
    mode = mode;
    _updateHistoryButtons();
    _updateNavigateButtons();
    _updateIndexText();
    Future.microtask(() => map._fixScaling());
  }

  GameMap get map => maps.isNotEmpty ? maps[mapIndex] : null;

  String _mode = 'draw';
  String get mode => _mode;
  set mode(String mode) {
    _mode = mode;
    _tools.querySelectorAll('.active:not(#mapShared)').classes.remove('active');
    _tools.querySelector('[mode=$mode]').classes.add('active');
    _setToolInfo(mode);

    _color.disabled = mode != 'draw';

    if (maps.isNotEmpty) {
      var wb = map.whiteboard;
      if (mode == 'erase') {
        wb.mode = Whiteboard.modeDraw;
        wb.eraser = true;
      } else {
        wb.mode = mode;
        wb.eraser = false;

        if (mode == 'draw') {
          wb.activeColor = _color.value;
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
    if (!user.session.isDM) {
      _tools.classes.toggle('hidden', !shared);
      map.whiteboard.captureInput = shared;
    }
  }

  void _updateNavigateButtons() {
    _navLeft.disabled = mapIndex == 0;

    if (user.session.isDM) {
      var showAdd = mapIndex == maps.length - 1;
      var icon = showAdd ? 'plus' : 'chevron-right';
      _navRight.classes.toggle('add-map', showAdd);
      _navRight.children.first.className = 'fas fa-$icon';

      if (showAdd && maps.length >= mapsPerCampaign) {
        _navRight.disabled = true;
        _navRight.querySelector('span').text =
            'Limit of $mapsPerCampaign Maps Reached!';
      } else {
        _navRight.disabled = maps.isEmpty;
        _navRight.querySelector('span').text = 'Create New Map';
      }
    } else {
      _navRight.disabled = mapIndex >= maps.length - 1;
    }
  }

  ButtonElement _toolBtn(String name) => _tools.querySelector('[action=$name]');

  void _updateHistoryButtons() {
    _toolBtn('clear').disabled = map.whiteboard.isClear;
    _toolBtn('undo').disabled = map.whiteboard.history.positionInStack == 0;
    _toolBtn('redo').disabled = !map.whiteboard.history.canRedo;
  }

  void _setToolInfo(String id) {
    var info = getToolInfo(id, user.session.isDM);

    if (info != null) {
      _toolInfo.innerHtml = info;
    }
  }

  Future<bool> _uploadNewMap(MouseEvent ev) async {
    if (maps.length >= mapsPerCampaign) return false;

    var id = await uploader.display(
      event: ev,
      action: GAME_MAP_CREATE,
      type: IMAGE_TYPE_MAP,
    );

    if (id != null) {
      addMap(id, '', false);
      _enterEdit(id);
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
      if (user.session.isDM && mapIndex == maps.length - 1) {
        await _uploadNewMap(ev);
      } else {
        mapIndex++;
      }
    });

    _imgButton.onLMB.listen(_uploadNewMap);
    _deleteButton.onClick.listen((_) => _deleteCurrentMap());

    _initTools();
    _initMapName();
    _shared.onClick.listen((_) {
      map.shared = !map.shared;
      shared = map.shared;
      socket.sendAction(GAME_MAP_UPDATE, {'map': map.id, 'shared': map.shared});
    });
  }

  void _initTools() {
    void registerAction(String name, void Function(MouseEvent ev) action) {
      ButtonElement button = _tools.querySelector('[action=$name]')
        ..onClick.listen(action);

      button.onMouseEnter.listen((_) => _setToolInfo(name));
      button.onMouseLeave.listen((_) => _setToolInfo(mode));
    }

    void clearMap() {
      map?.whiteboard?.clear();
      _toolBtn('clear').disabled = true;
    }

    _color.onInput.listen((_) {
      if (maps.isNotEmpty) {
        map.whiteboard.activeColor = _color.value;
      }
    });

    _tools.children[0].children.forEach((element) {
      if (element is ButtonElement) {
        element.onClick.listen((_) {
          mode = element.attributes['mode'];
        });
      }
    });

    registerAction('undo', (_) => map?.whiteboard?.history?.undo());
    registerAction('redo', (_) => map?.whiteboard?.history?.redo());
    registerAction('clear', (_) => clearMap());
    registerAction('change', (ev) async {
      var img = await uploader.display(
        event: ev,
        action: GAME_MAP_UPDATE,
        type: IMAGE_TYPE_MAP,
        extras: {'map': map.id},
      );

      if (img != null) {
        clearMap();
        map.reloadImage();
      }
    });

    _toolInfo.onClick.listen((_) => _setInfoVisible(false));
    _e.querySelector('#infoShow').onClick.listen((_) => _setInfoVisible(true));
    _tools.classes
        .toggle('collapsed', window.localStorage['mapToolInfo'] == 'false');
  }

  void _setInfoVisible(bool v) {
    _tools.classes.toggle('collapsed', !v);
    window.localStorage['mapToolInfo'] = '$v';
  }

  void _listenToEraseAcross() {
    window.onKeyDown.listen((ev) {
      if (ev.keyCode == 16) map?.whiteboard?.eraseAcrossLayers = true;
    });
    window.onKeyUp.listen((ev) {
      if (ev.keyCode == 16) map?.whiteboard?.eraseAcrossLayers = false;
    });
  }

  void _deleteCurrentMap() {
    socket.sendAction(GAME_MAP_REMOVE, {'map': map.id});
    onMapRemove(map.id);
  }

  void onMapRemove(int id) {
    var map = maps.firstWhere((m) => m.id == id).._dispose();
    maps.remove(map);
    if (maps.isEmpty) {
      _onAllRemoved();
    } else {
      mapIndex = min(max(mapIndex, 0), maps.length - 1);
    }
  }

  void _initMapName() {
    HtmlElement parent = _name.parent;
    ButtonElement confirmBtn = parent.querySelector('.dm');
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
        _name.value = map.name;
        parent.classes.remove('focus');
        focus = false;
      }
    });

    nameConfirm.listen((_) {
      if (focus) {
        focus = false;
        parent.classes.remove('focus');
        _name.blur();
        map.name = _name.value;
        socket
            .sendAction(GAME_MAP_UPDATE, {'map': map.id, 'name': _name.value});
      }
    });
  }

  void _onFirstUpload() {
    mapIndex = 0;
    if (user.session.isDM) {
      _name.disabled = false;
    }
  }

  void _onAllRemoved() {
    editMode = false;
    _updateNavigateButtons();
    _name.value = '';
    if (user.session.isDM) {
      _name.disabled = true;
    }
  }

  void fromJson(Iterable json) {
    maps.removeWhere((m) {
      m._em.remove();
      return true;
    });

    json.forEach((jMap) =>
        addMap(jMap['map'], jMap['name'], jMap['shared'], jMap['data']));
    if (maps.isNotEmpty) {
      _onFirstUpload();
    }

    if (user.session.isDM) {
      _color.value = '#000000';
    } else {
      _color.value = user.session.getPlayerColor(user.session.charId);
    }
    mode = Whiteboard.modeDraw;

    if (user.session.isDM) {
      _listenToEraseAcross();
    }
  }

  void _updateIndexText() => _indexText.text = '${mapIndex + 1}/${maps.length}';

  void addMap(int id, String name, bool shared, [String encodedData]) {
    var map = GameMap(id,
        name: name,
        shared: shared,
        encodedData: encodedData,
        onEnterEdit: () => _enterEdit(id));
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
      map.reloadImage();
    }
  }

  void handleEvent(Uint8List bytes) {
    var map = maps.firstWhere((m) => m.id == bytes.first);

    map.whiteboard.socket.handleEventBytes(bytes.sublist(1));
    map.updateMiniImage();
  }
}

class GameMap {
  final int id;
  HtmlElement _em;
  HtmlElement _container;
  HtmlElement _minimap;
  SpanElement _miniTitle;
  Whiteboard whiteboard;
  bool shared;

  String get name => _miniTitle.text;
  set name(String name) {
    _miniTitle.text = name;
  }

  GameMap(
    this.id, {
    String name = '',
    this.shared = false,
    String encodedData,
    void Function() onEnterEdit,
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

    whiteboard = Whiteboard(_container, textControlsWrapMin: 80)
      ..backgroundImageElement.crossOrigin = 'anonymous'
      ..socket.sendStream.listen((data) {
        updateMiniImage();
        socket.send(Uint8List.fromList([id, ...data]).buffer);
      });

    if (encodedData != null) {
      whiteboard.fromBytes(base64.decode(encodedData));
    } else {
      for (var i = 0; i <= user.session.characters.length; i++) {
        whiteboard.addDrawingLayer();
      }
    }

    // Assign user their own exclusive drawing layer
    whiteboard.layerIndex = 1 + (user.session.charId ?? -1);
    reloadImage();
  }

  void _dispose() {
    _em.remove();
    _minimap.remove();
  }

  void _fixScaling() {
    _container.style.width = '100%';
    whiteboard.updateScaling();
    var img = _container.querySelector('image');

    var bestWidth = img.getBoundingClientRect().width;
    if (bestWidth > 0) {
      _container.style.width = '${bestWidth}px';
      whiteboard.updateScaling();
    }
  }

  Future<void> updateMiniImage() async {
    var divide = 4;
    var canvas = CanvasElement(
      width: whiteboard.naturalWidth ~/ divide,
      height: whiteboard.naturalHeight ~/ divide,
    );
    canvas.context2D.scale(1 / divide, 1 / divide);
    whiteboard.drawToCanvas(canvas);
    var base64 = await uploader.canvasToBase64(canvas, includeHeader: true);
    _minimap.style.backgroundImage = "url('$base64')";
  }

  void reloadImage({bool cacheBreak = true}) async {
    var src = getGameFile('$IMAGE_TYPE_MAP$id', cacheBreak: cacheBreak);

    await whiteboard.changeBackground(src);
    await updateMiniImage();
    await Future.microtask(() => _fixScaling());
  }
}
