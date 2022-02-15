import 'dart:convert';
import 'dart:html';
import 'dart:math';

import 'package:meta/meta.dart';

import '../communication.dart';
import '../font_awesome.dart';
import '../game.dart';
import '../panels/dialog.dart';
import 'audioplayer.dart';
import 'board.dart';
import 'character.dart';
import 'demo.dart';
import 'log.dart';
import 'measuring.dart';
import 'prefab_palette.dart';
import 'scene.dart';

class Session extends Game {
  final bool isDM;
  final characters = <Character>[];
  final audioplayer = AudioPlayer();
  Board _board;
  Board get board => _board;
  int _charId;
  int get charId => _charId;
  Character get myCharacter => _charId != null ? characters[_charId] : null;
  String get inviteLink => isOnLocalHost
      ? 'http://localhost:8080/index.html?game=$id'
      : window.location.href;
  ConstantDialog _dmDisconnectedDialog;

  bool get isDemo => this is DemoSession;

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

  String getPlayerColor(int player, [int charCount]) {
    if (player == null) return '#ffffff'; // GM color

    var h = 330 * player / (charCount ?? characters.length);
    var l = 0.7 - 0.05 * cos(player * pi);

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

  void onKick(String reason) {
    socket.close();
    _dmDisconnectedDialog?.close();
    ConstantDialog('You Have Been Kicked')
      ..addParagraph(reason)
      ..append(ButtonElement()
        ..className = 'big'
        ..text = 'OK'
        ..onClick.listen((_) => window.location.reload()))
      ..display();
  }

  void onConnectionChange(Map<String, dynamic> params) async {
    bool join = params['join'];
    int id = params['pc'];

    if (id >= 0) {
      var pc = characters[id];
      var name = pc?.name;

      pc.hasJoined = join;
      if (join) {
        gameLog('$name joined the game.');
      } else {
        gameLog('$name left the game.');
        removeMeasuring(id);
      }
    } else {
      if (!join) {
        _dmDisconnectedDialog = ConstantDialog('Your GM Disconnected')
          ..addParagraph('''
              If they happen to reconnect anytime soon,
              you'll return to the game.''')
          ..append(icon('spinner')..classes.add('spinner'))
          ..display();
        removeMeasuring(null);
      } else {
        if (_dmDisconnectedDialog != null) {
          _dmDisconnectedDialog.close();
          _dmDisconnectedDialog = null;
        }
      }
    }
  }

  Future<void> initialize({
    @required Iterable<Character> characters,
    @required int playingId,
    @required int sceneCount,
    bool instantEdit = false,
    int charId,
    Map ambienceJson = const {},
    Iterable prefabJsonList = const [],
    Map sceneJson,
    Iterable mapJsonList = const [],
  }) {
    this.characters.clear();
    this.characters.addAll(characters);
    _charId = charId;

    if (isDM) {
      logInviteLink(this);
    } else {
      gameLog('Hello, ${myCharacter.name}!', mine: true);
    }

    audioplayer.init(this, ambienceJson);

    // Depends on global session object
    return Future.microtask(() async {
      initMovableManager(prefabJsonList);
      if (sceneJson != null) {
        _board.fromJson(playingId, sceneJson);
      } else {
        await _board.onSceneChange(playingId);
        _board.resetTransform();
      }

      querySelector('#session').classes.toggle('is-dm', isDM);

      _board.mapTab.fromJson(mapJsonList ?? []);

      if (isDM) {
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

  void fromJson(Map<String, dynamic> json, {bool instantEdit = false}) {
    var chars = <Character>[];
    var pcs = List.from(json['pcs']);
    for (var i = 0; i < pcs.length; i++) {
      chars.add(
          Character.fromJson(i, getPlayerColor(i, pcs.length), this, pcs[i]));
    }

    initialize(
      characters: chars,
      charId: json['mine'],
      ambienceJson: json['ambience'],
      instantEdit: instantEdit,
      playingId: json['sceneId'],
      sceneCount: isDM ? json['dm']['scenes'] : null,
      mapJsonList: json['maps'] ?? [],
      prefabJsonList: json['prefabs'],
      sceneJson: json['scene'],
    );
  }
}
