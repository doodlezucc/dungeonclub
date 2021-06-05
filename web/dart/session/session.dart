import 'dart:convert';
import 'dart:html';

import '../game.dart';
import 'board.dart';
import 'character.dart';
import 'log.dart';
import 'prefab_palette.dart';
import 'scene.dart';

class Session extends Game {
  final bool isDM;
  final characters = <Character>[];
  Board _board;
  Board get board => _board;
  int _charId;
  int get charId => _charId;
  Character get myCharacter => _charId != null ? characters[_charId] : null;

  Session(String id, String name, this.isDM) : super(id, name, null) {
    _board = Board(this);

    var url = window.location.href;

    if (!url.contains(id) && !url.contains(':8080')) {
      window.history.pushState({}, '', 'game/$id');
    }

    if (!isDM) {
      _saveGameId();
    }
  }

  void _saveGameId() {
    var idNames = Map<String, String>.from(
        jsonDecode(window.localStorage['joined'] ?? '{}'));

    // Add joined game id and name to local storage
    idNames[id] = name;
    window.localStorage['joined'] = jsonEncode(idNames);
  }

  void fromJson(Map<String, dynamic> json) {
    characters.clear();
    var pcs = List.from(json['pcs']);
    for (var i = 0; i < pcs.length; i++) {
      characters.add(Character(i, pcs[i]));
    }

    _charId = json['mine'];
    gameLog('Hello, ' + (myCharacter?.name ?? 'DM') + '!', mine: true);

    // Depends on global session object
    Future.microtask(() {
      int playingId = json['sceneId'];
      initMovableManager(json['prefabs']);
      _board.fromJson(playingId, json['scene']);

      querySelector('#session').classes.toggle('is-dm', isDM);

      _board.mapTab.fromJson(json['maps'] ?? []);

      if (isDM) {
        int sceneCount = json['dm']['scenes'];
        for (var i = 0; i < sceneCount; i++) {
          var scene = Scene(i);
          if (i == playingId) {
            _board.refScene = scene
              ..editing = true
              ..playing = true;

            if (sceneCount == 1) {
              scene.enableRemove = false;
            }
          }
        }
      }
    });
  }
}
