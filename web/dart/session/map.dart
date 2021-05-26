import 'dart:convert';
import 'dart:html';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:dnd_interactive/actions.dart';
import 'package:web_whiteboard/communication/web_socket.dart';
import 'package:web_whiteboard/whiteboard.dart';

import '../../main.dart';
import '../communication.dart';
import '../panels/upload.dart' as uploader;

final HtmlElement _e = querySelector('#map');
final HtmlElement _mapContainer = _e.querySelector('#maps');
final ButtonElement _backButton = _e.querySelector('button[type=reset]');
final ButtonElement _imgButton = _e.querySelector('#changeMap');
final InputElement _name = _e.querySelector('#mapName');
final HtmlElement _tools = _e.querySelector('#mapTools');

class MapTab {
  final maps = <GameMap>[];

  int _currentMap = 0;
  int get mapIndex => _currentMap;
  set mapIndex(int currentMap) {
    _currentMap = currentMap;
    _mapContainer.style.left = '${currentMap * -100}%';
    _name.value = map.name;
    map.whiteboard.mode = mode;
    _updateButtons();
  }

  GameMap get map => maps.isNotEmpty ? maps[mapIndex] : null;

  String _mode;
  String get mode => _mode;
  set mode(String mode) {
    _mode = mode;
    _tools.querySelectorAll('.active').classes.remove('active');
    _tools.querySelector('[mode=$mode]').classes.add('active');

    if (maps.isNotEmpty) {
      var wb = maps[mapIndex].whiteboard;
      if (mode == 'erase') {
        wb.mode = 'draw';
        wb.eraser = true;
      } else {
        wb.mode = mode;
        wb.eraser = false;
      }
    }
  }

  bool get visible => _e.classes.contains('show');
  set visible(bool visible) {
    _e.classes.toggle('show', visible);
  }

  ButtonElement _toolBtn(String name) => _tools.querySelector('[action=$name]');

  void _updateButtons() {
    _toolBtn('clear').disabled = map.whiteboard.isClear;
    _toolBtn('undo').disabled = map.whiteboard.history.positionInStack == 0;
    _toolBtn('redo').disabled = !map.whiteboard.history.canRedo;
  }

  void initMapControls() {
    _backButton.onClick.listen((_) => visible = false);
    visible = true;

    window.onKeyDown.listen((ev) {
      if (!visible ||
          ev.target is InputElement ||
          ev.target is TextAreaElement) {
        return;
      }

      if (ev.keyCode == 27) {
        ev.preventDefault();
        visible = false;
        // Arrow key controls
      } else if (ev.keyCode == 37 && mapIndex > 0) {
        mapIndex--;
      } else if (ev.keyCode == 39 && mapIndex < maps.length - 1) {
        mapIndex++;
      }
    });

    _imgButton.onClick.listen((_) async {
      if (maps.isEmpty) {
        var id = await uploader.display(
          action: GAME_MAP_CREATE,
          type: IMAGE_TYPE_MAP,
        );

        if (id != null) addMap(id, '');
      }
    });

    _tools.children[0].children.forEach((element) {
      if (element is ButtonElement) {
        element.onClick.listen((_) {
          mode = element.attributes['mode'];
        });
      }
    });

    void registerAction(String name, void Function() action) {
      _tools.querySelector('[action=$name]').onClick.listen((_) => action());
    }

    void clearMap() {
      map?.whiteboard?.clear();
      _toolBtn('clear').disabled = true;
    }

    registerAction('undo', () => map?.whiteboard?.history?.undo());
    registerAction('redo', () => map?.whiteboard?.history?.redo());
    registerAction('clear', () => clearMap());
    registerAction('change', () async {
      var img = await uploader.display(
        action: GAME_MAP_UPDATE,
        type: IMAGE_TYPE_MAP,
        extras: {'map': map.id},
      );

      if (img != null) {
        clearMap();
        map.reloadImage();
      }
    });

    _initMapName();

    mode = Whiteboard.modeDraw;
  }

  void _initMapName() {
    ButtonElement confirmBtn = _name.nextElementSibling;
    var nameConfirm = StreamGroup.merge(<Stream>[
      _name.onKeyDown.where((ev) => ev.keyCode == 13),
      confirmBtn.onMouseDown,
    ]);

    var focus = false;
    String bufferedName;
    _name.onFocus.listen((_) {
      focus = true;
      bufferedName = _name.value;
    });
    _name.onInput.listen((_) => confirmBtn.classes.remove('hidden'));
    _name.onBlur.listen((_) async {
      await Future.delayed(Duration(milliseconds: 50));
      if (focus) {
        _name.value = bufferedName;
        confirmBtn.classes.add('hidden');
        focus = false;
      }
    });

    nameConfirm.listen((_) {
      if (focus) {
        focus = false;
        confirmBtn.classes.add('hidden');
        _name.blur();
        socket.sendAction(
            GAME_MAP_UPDATE, {'map': mapIndex, 'name': _name.value});
      }
    });
  }

  void _onFirstUpload() {
    mapIndex = 0;
    _imgButton.remove();
    _tools.classes.remove('hidden');
    if (user.session.isDM) {
      _name.disabled = false;
    }
  }

  void fromJson(Iterable json) {
    maps.removeWhere((m) {
      m._em.remove();
      return true;
    });

    json.forEach((jMap) => addMap(jMap['id'], jMap['name'], jMap['data']));
    if (maps.isNotEmpty) {
      _onFirstUpload();
    }
  }

  void addMap(int id, String name, [String encodedData]) {
    var map = GameMap(id, name: name, encodedData: encodedData);
    map.whiteboard.history.onChange.listen((_) => _updateButtons());
    maps.add(map);

    if (maps.length == 1) _onFirstUpload();
  }

  void onMapUpdate(Map<String, dynamic> json) {
    var map = maps.firstWhere((m) => m.id == json['map']);
    var name = json['name'];
    if (name != null) {
      map.name = name;
      if (maps[mapIndex] == map) _name.value = map.name;
    } else {
      map.reloadImage();
    }
  }

  void handleEvent(Blob blob) async {
    var bytes = await blobToBytes(blob);
    maps[bytes.first].whiteboard.socket.handleEventBytes(bytes.sublist(1));
  }
}

class GameMap {
  final int id;
  HtmlElement _em;
  HtmlElement _container;
  Whiteboard whiteboard;

  String name;

  GameMap(this.id, {this.name = '', String encodedData}) {
    _em = DivElement()
      ..className = 'map'
      ..append(_container = DivElement());

    _mapContainer.append(_em);

    whiteboard = Whiteboard(_container)
      ..socket.sendStream.listen(
          (data) => socket.send(Uint8List.fromList([id, ...data]).buffer));

    if (encodedData != null) {
      whiteboard.fromBytes(base64.decode(encodedData));
    } else {
      for (var i = 0; i <= user.session.characters.length; i++) {
        whiteboard.addDrawingLayer();
      }
    }

    // Assign user their own exclusive drawing layer
    whiteboard.layerIndex = 1 + (user.session.charId ?? -1);
    reloadImage(cacheBreak: false);

    window.onResize.listen((_) => _fixScaling());
  }

  void _fixScaling() {
    _container.style.width = '100%';
    whiteboard.updateScaling();
    var img = _container.querySelector('image');

    var bestWidth = img.getBoundingClientRect().width;
    _container.style.width = '${bestWidth}px';
    whiteboard.updateScaling();
  }

  void reloadImage({bool cacheBreak = true}) async {
    var src = getGameFile('$IMAGE_TYPE_MAP$id.png', cacheBreak: cacheBreak);

    await whiteboard.changeBackground(src);
    _fixScaling();
  }
}
