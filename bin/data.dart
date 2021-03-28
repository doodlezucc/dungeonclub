import 'dart:async';
import 'dart:convert';

import 'dart:io';
import 'dart:math';

import 'package:crypt/crypt.dart';
import 'package:dnd_interactive/actions.dart' as a;
import 'package:dnd_interactive/point_json.dart';
import 'package:path/path.dart' as path;
import 'package:random_string/random_string.dart';

import 'connections.dart';
import 'server.dart';

class ServerData {
  static final _manualSaveWatch = Stopwatch();
  static final directory = Directory('database');
  static final file = File(path.join(directory.path, 'data.json'));

  final accounts = <Account>[];
  final games = <Game>[];
  final Random rng = Random();

  void init() {
    load().then((_) {
      _manualSaveWatch.start();
      //initAutoSave();
    });
  }

  void initAutoSave() {
    Timer.periodic(Duration(seconds: 10), (timer) {
      save();
    });
  }

  Account getAccount(String email, {bool alreadyEncrypted = false}) {
    if (email == null) return null;
    return accounts.firstWhere(
        (p) => alreadyEncrypted
            ? p.encryptedEmail.toString() == email
            : p.encryptedEmail.match(email),
        orElse: () => null);
  }

  Map<String, dynamic> toJson() => {
        'accounts': accounts.map((e) => e.toJson()).toList(),
        'games': games.map((e) => e.toJson()).toList(),
      };

  void fromJson(Map<String, dynamic> json) {
    var owners = <Game, String>{};

    games.clear();
    games.addAll(List.from(json['games']).map((j) {
      var game = Game.fromJson(j);
      owners[game] = j['owner'];
      return game;
    }));
    print('Loaded ${games.length} games');

    accounts.clear();
    accounts
        .addAll(List.from(json['accounts']).map((j) => Account.fromJson(j)));
    print('Loaded ${accounts.length} accounts');

    owners.forEach((game, ownerEmail) {
      game.owner = data.getAccount(ownerEmail, alreadyEncrypted: true);
    });
    print('Set all game owners');
  }

  Future<void> save() async {
    var json = JsonEncoder.withIndent(' ').convert(toJson());
    print(json);
    await file.writeAsString(json);
    print('Saved!');
  }

  Future<void> load() async {
    if (!await file.exists()) return;

    var s = await file.readAsString();
    var json = jsonDecode(s);
    fromJson(json);
    print('Loaded!');
  }

  Future<void> manualSave() async {
    if (_manualSaveWatch.elapsedMilliseconds > 1000) {
      await save();
    } else {
      print('Manual saving has a cooldown.');
    }
    _manualSaveWatch.reset();
  }
}

class Account {
  final Crypt encryptedEmail;
  Crypt encryptedPassword;

  var enteredGames = <Game>[];
  Iterable<Game> get ownedGames => enteredGames.where((g) => g.owner == this);

  Account(String email, String password)
      : encryptedEmail = Crypt.sha256(email),
        encryptedPassword = Crypt.sha256(password);

  bool ownsGame(String gameId) {
    return enteredGames.any((g) => g.id == gameId && g.owner == this);
  }

  Account.fromJson(Map<String, dynamic> json)
      : encryptedEmail = Crypt(json['email']),
        encryptedPassword = Crypt(json['password']),
        enteredGames = List.from(json['games'])
            .map((id) => data.games.firstWhere(
                  (g) => g.id == id,
                  orElse: () => null,
                ))
            .where((g) => g != null)
            .toList();

  Map<String, dynamic> toJson() => {
        'email': encryptedEmail.toString(),
        'password': encryptedPassword.toString(),
        'games': enteredGames.map((g) => g.id).toList(),
      };

  Map<String, dynamic> toSnippet() => {
        'games': enteredGames.map((g) => g.toSnippet(this)).toList(),
      };
}

class Game {
  final String id;
  Directory get resources =>
      Directory(path.join(ServerData.directory.path, 'games', id));
  String name;
  Account owner;

  Connection get gm =>
      _connections.firstWhere((c) => owner == c.account, orElse: () => null);
  bool get gmOnline => gm != null;
  int get online => _connections.length;
  int get sceneCount => _scenes.length;
  Scene get playingScene =>
      playingSceneId < _scenes.length ? _scenes[playingSceneId] : null;

  final _connections = <Connection>[];
  final List<PlayerCharacter> _characters;
  final List<Scene> _scenes;
  final List<CustomPrefab> _prefabs;
  int playingSceneId = 0;

  static String _generateId() {
    String id;
    do {
      id = randomAlphaNumeric(10);
    } while (data.games.any((g) => g.id == id));
    return id;
  }

  void notify(String action, Map<String, dynamic> params,
      {Connection exclude, bool allScenes = false}) {
    for (var c in _connections) {
      if (exclude == null ||
          (c != exclude && (allScenes || c.scene == exclude.scene))) {
        c.sendAction(action, params);
      }
    }
  }

  Future<File> getFile(String filePath) async {
    if (!await resources.exists()) {
      await resources.create(recursive: true);
    }
    return File(path.join(resources.path, filePath));
  }

  Game(this.owner, this.name)
      : id = _generateId(),
        _scenes = [Scene({})],
        _characters = [],
        _prefabs = [];

  void connect(Connection connection, bool join) {
    notify(a.GAME_CONNECTION, {
      'join': join,
      'pc': _characters.indexWhere((e) => e.connection == connection),
    });
    if (!join) {
      _connections.remove(connection);
      return;
    }
    _connections.add(connection);
  }

  void playScene(int id) {
    playingSceneId = id;
    var scene = playingScene;
    for (var c in connections) {
      c.scene = scene;
    }
  }

  void addPC(String name) {
    _characters.add(PlayerCharacter(name));
  }

  void removePC(int index) {
    _characters.removeAt(index);
  }

  CustomPrefab addPrefab() {
    var p = CustomPrefab(_prefabs.length, 1);
    _prefabs.add(p);
    return p;
  }

  EntityBase getPrefab(String id) {
    var isPC = id[0] == 'c';
    if (isPC) {
      return _characters[int.parse(id.substring(1))].prefab;
    }

    return _prefabs.firstWhere((p) => p.id == int.parse(id),
        orElse: () => null);
  }

  Future<String> uploadImage(String type, int id, String base64) async {
    var file = await (await getFile('$type$id.png')).create();
    return '$address/${file.path}';
  }

  Future<void> delete() async {
    if (await resources.exists()) {
      await resources.delete(recursive: true);
    }
    data.games.remove(this);
    owner.enteredGames.remove(this);
  }

  Scene getScene(int id) =>
      (id != null && id < _scenes.length) ? _scenes[id] : null;

  Scene addScene() {
    var scene = Scene({});
    _scenes.add(scene);
    return scene;
  }

  Future<bool> removeScene(int id) async {
    if (_scenes.length <= 1) return false;

    if (id != null && id < _scenes.length) {
      var img = await getSceneFile(id);
      await img.delete();
      for (var i = id + 1; i < _scenes.length; i++) {
        var file = await getSceneFile(i);
        await file.rename((await getSceneFile(i - 1)).path);
      }
      _scenes.removeAt(id);

      // update playing scene id
      if (id == playingSceneId) {
        playScene(max(0, id - 1));
      } else if (playingSceneId > id) {
        playingSceneId = max(0, playingSceneId - 1);
      }
      return true;
    }
    return false;
  }

  Future<File> getSceneFile(int id) async {
    return await getFile('${a.IMAGE_TYPE_SCENE}$id.png');
  }

  PlayerCharacter assignPC(int index, Connection c) {
    return _characters[index]..connection = c;
  }

  Game.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        name = json['name'],
        playingSceneId = json['scene'] ?? 0,
        _scenes = List.from(json['scenes']).map((e) => Scene(e)).toList(),
        _characters = List.from(json['pcs'])
            .map((j) => PlayerCharacter.fromJson(j))
            .toList(),
        _prefabs = List.from(json['prefabs'] ?? [])
            .map((e) => CustomPrefab.fromJson(e))
            .toList();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'owner': owner.encryptedEmail.toString(),
        'scene': playingSceneId,
        'pcs': _characters.map((e) => e.toJson()).toList(),
        'scenes': _scenes.map((e) => e.toJson()).toList(),
        'prefabs': _prefabs.map((e) => e.toJson()).toList(),
      };

  Map<String, dynamic> toSnippet(Account acc) => {
        'id': id,
        'name': name,
        'mine': acc == owner,
      };

  Map<String, dynamic> toSessionSnippet(Connection c, [int mine]) {
    return {
      'id': id,
      'sceneId': playingSceneId,
      'scene': playingScene.toJson(),
      'pcs': _characters.map((e) => e.toJson()).toList(),
      if (mine != null) 'mine': mine,
      'prefabs': _prefabs.map((e) => e.toJson()).toList(),
      if (owner == c.account) 'gm': {'scenes': _scenes.length},
    };
  }

  bool applyChanges(Map<String, dynamic> data) {
    _characters.clear();
    name = data['name'];
    var pcs = List.from(data['pcs']);
    if (pcs.length >= 20) return false;
    _characters.addAll(pcs.map((e) => PlayerCharacter.fromJson(e)));
    return true;
  }
}

class PlayerCharacter {
  Connection connection;
  String name;
  final CharacterPrefab prefab;

  PlayerCharacter(this.name) : prefab = CharacterPrefab();
  PlayerCharacter.fromJson(Map<String, dynamic> json)
      : name = json['name'],
        prefab = CharacterPrefab()..fromJson(json['prefab'] ?? {});

  Map<String, dynamic> toJson() => {
        'name': name,
        'prefab': prefab.toJson(),
      };
}

class Scene {
  final List<Movable> _movables;
  int _countMIDs;
  Point gridOffset;
  num cellSize;
  String gridColor;

  Scene(Map<String, dynamic> json)
      : _movables = List.from(json['movables'] ?? [])
            .map((j) => Movable(j['id'], j))
            .toList() {
    _countMIDs = _movables.fold(-1, (v, m) => max<int>(v, m.id)) + 1;
    applyGrid(json['grid'] ?? {});
  }

  Movable addMovable(Map<String, dynamic> json) {
    var m = Movable(_countMIDs++, json);
    _movables.add(m);
    return m;
  }

  Movable getMovable(int id) {
    return _movables.singleWhere((m) => m.id == id, orElse: () => null);
  }

  void removeMovable(int id) {
    _movables.removeWhere((m) => m.id == id);
  }

  void applyGrid(Map<String, dynamic> json) {
    gridOffset = parsePoint(json['offset']) ?? Point(0, 0);
    cellSize = json['cellSize'] ?? 100;
    gridColor = json['color'] ?? '#000000';
  }

  void applyMovables(Iterable jsons) {
    for (var mj in jsons) {
      var id = mj['id'];
      var m = _movables.firstWhere((m) => m.id == id, orElse: () => null);
      if (m != null) {
        var point = parsePoint(mj);
        m.x = point.x;
        m.y = point.y;
      }
    }
  }

  Map<String, dynamic> toJson() => {
        'grid': {
          'offset': writePoint(gridOffset),
          'cellSize': cellSize,
          'color': gridColor,
        },
        'movables': _movables.map((e) => e.toJson()).toList(),
      };
}

abstract class EntityBase {
  int size = 0;

  EntityBase({this.size});

  void fromJson(Map<String, dynamic> json) {
    size = json['size'] ?? 1;
  }

  Map<String, dynamic> toJson() => {
        'size': size,
      };
}

class CharacterPrefab extends EntityBase {
  CharacterPrefab({int size}) : super(size: size);
  CharacterPrefab.fromJson(Map<String, dynamic> json) {
    fromJson(json);
  }
}

class CustomPrefab extends EntityBase {
  final int id;
  String name;

  CustomPrefab(this.id, int size) : super(size: size);
  CustomPrefab.fromJson(Map<String, dynamic> json) : id = json['id'] {
    fromJson(json);
  }

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    name = json['name'];
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        ...super.toJson(),
      };
}

class Movable extends EntityBase {
  final int id;
  String prefab;
  num x;
  num y;

  Movable(int id, Map<String, dynamic> json)
      : id = id,
        prefab = json['prefab'],
        x = json['x'],
        y = json['y'] {
    fromJson(json);
  }

  @override
  void fromJson(Map<String, dynamic> json) {
    size = json['size'] ?? 0;
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'prefab': prefab,
        'x': x,
        'y': y,
        ...super.toJson(),
      };
}
