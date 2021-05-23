import 'dart:convert';
import 'dart:html';
import 'dart:typed_data';

import 'package:dnd_interactive/actions.dart';
import 'package:web_whiteboard/whiteboard.dart';

import '../../main.dart';
import '../communication.dart';
import '../panels/upload.dart' as uploader;

final HtmlElement _e = querySelector('#map');
final HtmlElement _mapContainer = _e.querySelector('#maps');
final ButtonElement _backButton = _e.querySelector('button[type=reset]');
final ButtonElement _imgButton = _e.querySelector('#changeMap');
final InputElement _name = _e.querySelector('#mapName');

class MapTab {
  final maps = <GameMap>[];

  int _currentMap = 0;
  int get currentMap => _currentMap;
  set currentMap(int currentMap) {
    _currentMap = currentMap;
    _mapContainer.style.left = '${currentMap * -100}%';
    _name.value = maps[currentMap].name;
  }

  bool get visible => _e.classes.contains('show');
  set visible(bool visible) {
    _e.classes.toggle('show', visible);
  }

  void initMapControls() {
    _backButton.onClick.listen((_) => visible = false);
    visible = true;

    window.onKeyDown.listen((ev) {
      if (!visible || ev.target is InputElement) return;

      if (ev.keyCode == 27) {
        ev.preventDefault();
        visible = false;
        // Arrow key controls
      } else if (ev.keyCode == 37 && currentMap > 0) {
        currentMap--;
      } else if (ev.keyCode == 39 && currentMap < maps.length - 1) {
        currentMap++;
      }
    });

    _imgButton.onClick.listen((_) async {
      if (maps.isEmpty) {
        var id = await uploader.display(
          action: GAME_MAP_CREATE,
          type: IMAGE_TYPE_MAP,
        );

        if (id != null) addMap(id, '');
      } else {
        var map = maps[currentMap];

        var img = await uploader.display(
          action: GAME_MAP_UPDATE,
          type: IMAGE_TYPE_MAP,
          extras: {'id': map.id},
        );

        if (img != null) {
          map.reloadImage();
        }
      }
    });
  }

  void _onFirstUpload() {
    currentMap = 0;
    _imgButton.text = 'Change image';
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
    var map = GameMap(0, name: name, encodedData: encodedData);
    maps.add(map);

    if (maps.length == 1) _onFirstUpload();
  }

  void onMapUpdate(Map<String, dynamic> json) {
    var map = maps.firstWhere((m) => m.id == json['id']);
    var name = json['name'];
    if (name != null) {
      map.name = name;
      if (maps[currentMap] == map) _name.value = map.name;
    } else {
      map.reloadImage();
    }
  }

  void handleEvent(Uint8List bytes) {
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
      ..mode = Whiteboard.modeDraw
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
  }

  void reloadImage({bool cacheBreak = true}) async {
    var src = getGameFile('$IMAGE_TYPE_MAP$id.png', cacheBreak: cacheBreak);

    _container.style.width = '100%';
    await whiteboard.changeBackground(src);
    var img = _container.querySelector('image');

    var bestWidth = img.getBoundingClientRect().width;
    _container.style.width = '${bestWidth}px';
    whiteboard.updateScaling();
    whiteboard.updateScaling();
  }
}
