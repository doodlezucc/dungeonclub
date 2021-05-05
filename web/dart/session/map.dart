import 'dart:html';

import 'package:dnd_interactive/actions.dart';

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

    json.forEach((jMap) => addMap(jMap['id'], jMap['name']));
    if (maps.isNotEmpty) {
      _onFirstUpload();
    }
  }

  void addMap(int id, String name) {
    maps.add(GameMap(0, name: name));
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
}

class GameMap {
  final int id;
  HtmlElement _em;
  HtmlElement _img;

  String name;

  set image(String image) {
    _img.style.backgroundImage = 'url($image)';
  }

  GameMap(this.id, {this.name = ''}) {
    _em = DivElement()
      ..className = 'map'
      ..append(_img = DivElement()..className = 'background');

    reloadImage(cacheBreak: false);
    _mapContainer.append(_em);
  }

  void reloadImage({bool cacheBreak = true}) {
    image = getGameFile('$IMAGE_TYPE_MAP$id.png', cacheBreak: cacheBreak);
  }
}
