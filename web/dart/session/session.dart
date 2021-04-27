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
  }

  void fromJson(Map<String, dynamic> json) {
    characters.clear();
    var pcs = List.from(json['pcs']);
    for (var i = 0; i < pcs.length; i++) {
      characters.add(Character(i, pcs[i]));
    }

    _charId = json['mine'];
    gameLog('Hello, ' + (myCharacter?.name ?? 'GM') + '!');

    // Depends on global session object
    Future.microtask(() {
      int playingId = json['sceneId'];
      initMovableManager(json['prefabs']);
      _board.fromJson(playingId, json['scene']);

      querySelector('#session').classes.toggle('is-gm', isDM);

      if (isDM) {
        int sceneCount = json['gm']['scenes'];
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
