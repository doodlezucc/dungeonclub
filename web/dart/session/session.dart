import 'dart:convert';
import 'dart:html';
import 'dart:math';

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

  String getPlayerColor(int player) {
    if (player == null) return '#ffffff'; // DM color

    var h = 360 * player / characters.length;
    var l = 0.65 + 0.1 * sin(player);

    // Convert from HSL to RGB
    var c = 1 - (2 * l - 1).abs();
    var x = c * (1 - ((h / 60) % 2 - 1).abs());
    var m = l - c / 2;

    var r = (h < 60 || h >= 300) ? c : ((h < 120 || h >= 240) ? x : 0);
    var g = h >= 240 ? 0 : ((h < 60 || h >= 180) ? x : c);
    var b = h < 120 ? 0 : ((h < 180 || h >= 300) ? x : c);

    String hex(double v) =>
        ((v + m) * 255).round().toRadixString(16).padLeft(2, '0');

    return '#' + hex(r) + hex(g) + hex(b);
  }

  void onConnectionChange(Map<String, dynamic> params) {
    bool join = params['join'];
    int id = params['pc'];
    var pc = characters[id];

    var name = pc?.name ?? 'DM';

    pc.hasJoined = join;
    if (join) {
      gameLog('$name joined the game.');
    } else {
      gameLog('$name left the game.');
    }
  }

  void fromJson(Map<String, dynamic> json, {bool instantEdit = false}) {
    characters.clear();
    var pcs = List.from(json['pcs']);
    for (var i = 0; i < pcs.length; i++) {
      characters.add(Character(i, pcs[i]));
    }

    _charId = json['mine'];
    gameLog('Hello, ' + (myCharacter?.name ?? 'DM') + '!', mine: true);

    // Depends on global session object
    Future.microtask(() {
      print(json);
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

        if (instantEdit) {
          _board.editingGrid = true;
        }
      }
    });
  }
}
