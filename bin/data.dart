import 'dart:async';
import 'dart:convert';

import 'dart:io';
import 'dart:math';

import 'package:crypt/crypt.dart';
import 'package:dnd_interactive/actions.dart' as a;
import 'package:dnd_interactive/point_json.dart';
import 'package:path/path.dart' as path;
import 'package:random_string/random_string.dart';
import 'package:web_whiteboard/communication/data_socket.dart';
import 'package:web_whiteboard/layers/drawing_data.dart';
import 'package:web_whiteboard/whiteboard_data.dart';

import 'connections.dart';
import 'server.dart';

class ServerData {
  static final _manualSaveWatch = Stopwatch();
  static final directory = Directory('database');
  static final file = File(path.join(directory.path, 'data.json'));

  final accounts = <Account>[];
  final games = <Game>[];
  final Random rng = Random();

  void init() async {
    await load();
    _manualSaveWatch.start();
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
    // print(json);

    if (!await file.exists()) {
      await file.create(recursive: true);
    }

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

  Connection get dm =>
      _connections.firstWhere((c) => owner == c.account, orElse: () => null);
  bool get dmOnline => dm != null;
  int get online => _connections.length;
  int get sceneCount => _scenes.length;
  Scene get playingScene =>
      playingSceneId < _scenes.length ? _scenes[playingSceneId] : null;
  Iterable<PlayerCharacter> get characters => _characters;
  int get prefabCount => _prefabs.length;
  int get mapCount => _maps.length;

  int get _nextPrefabId => _prefabs.fold(-1, (v, m) => max<int>(v, m.id)) + 1;
  int get _nextMapId => _maps.fold(-1, (v, m) => max<int>(v, m.id)) + 1;

  final _connections = <Connection>[];
  final List<PlayerCharacter> _characters;
  final List<Scene> _scenes;
  final List<CustomPrefab> _prefabs;
  final List<GameMap> _maps;
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
        _prefabs = [],
        _maps = [];

  void connect(Connection connection, bool join) {
    var pc = _characters.firstWhere(
      (e) => e.connection == connection,
      orElse: () => null,
    );

    notify(a.GAME_CONNECTION, {
      'join': join,
      'pc': _characters.indexOf(pc),
    });

    if (!join) {
      pc?.connection = null;
      _connections.remove(connection);
    } else {
      _connections.add(connection);
    }
  }

  void playScene(int id) {
    playingSceneId = id;
    var scene = playingScene;
    for (var c in connections) {
      c.scene = scene;
    }
  }

  CustomPrefab addPrefab() {
    var p = CustomPrefab(_nextPrefabId, 1);
    _prefabs.add(p);
    return p;
  }

  EntityBase getPrefab(String id) {
    var isPC = id[0] == 'c';
    if (isPC) {
      return _characters[int.parse(id.substring(1))].prefab;
    }

    return getCustomPrefab(id);
  }

  CustomPrefab getCustomPrefab(String id) {
    var parsed = int.tryParse(id) ?? -1;
    return _prefabs.firstWhere((p) => p.id == parsed, orElse: () => null);
  }

  void removePrefab(String id) async {
    var prefab = getCustomPrefab(id);
    if (prefab == null) return null;

    _prefabs.remove(prefab);
    for (var scene in _scenes) {
      scene.removeMovablesOfPrefab(id);
    }
    var file = await getPrefabFile(id);
    await file.delete();
  }

  Future<String> uploadImage(String type, int id, String base64) async {
    var file = await (await getFile('$type$id')).create();
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
    return await getFile('${a.IMAGE_TYPE_SCENE}$id');
  }

  Future<File> getPrefabFile(dynamic id) async {
    return await getFile('${a.IMAGE_TYPE_ENTITY}$id');
  }

  PlayerCharacter assignPC(int index, Connection c) {
    return _characters[index]..connection = c;
  }

  int addMap() {
    var map = GameMap(_nextMapId, '');
    for (var i = 0; i <= _characters.length; i++) {
      map.data.layers.add(DrawingData());
    }
    _maps.add(map);
    return map.id;
  }

  void updateMap(int id, String name) =>
      _maps.firstWhere((m) => m.id == id).name = name;

  void removeMap(int id) async {
    _maps.removeWhere((m) => m.id == id);
    var file = await getFile('${a.IMAGE_TYPE_MAP}$id');
    await file.delete();
  }

  void handleMapEvent(List<int> bytes, Connection sender) {
    var mapIndex = bytes[0];
    var map = _maps.firstWhere((m) => m.id == mapIndex);
    if (map.dataSocket.handleEvent(bytes.sublist(1))) {
      for (var conni in connections) {
        if (conni != sender) {
          conni.send(bytes);
        }
      }
    }
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
            .map((j) => CustomPrefab.fromJson(j))
            .toList(),
        _maps = List.from(json['maps'] ?? [])
            .map((j) => GameMap.fromJson(j))
            .toList();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'owner': owner.encryptedEmail.toString(),
        'scene': playingSceneId,
        'pcs': _characters.map((e) => e.toJson()).toList(),
        'scenes': _scenes.map((e) => e.toJson()).toList(),
        'prefabs': _prefabs.map((e) => e.toJson()).toList(),
        'maps': _maps.map((e) => e.toJson()).toList(),
      };

  Map<String, dynamic> toSnippet(Account acc) => {
        'id': id,
        'name': name,
        'mine': acc == owner,
      };

  Map<String, dynamic> toSessionSnippet(Connection c, [int mine]) {
    return {
      'id': id,
      'name': name,
      'sceneId': playingSceneId,
      'scene': playingScene.toJson(),
      'pcs': _characters.map((e) => e.toJson(includeStatus: true)).toList(),
      'maps': _maps.map((e) => e.toJson()).toList(),
      if (mine != null) 'mine': mine,
      'prefabs': _prefabs.map((e) => e.toJson()).toList(),
      if (owner == c.account) 'dm': {'scenes': _scenes.length},
    };
  }

  bool applyChanges(Map<String, dynamic> data) {
    var charCount = _characters.length;
    _characters.clear();
    name = data['name'];
    var pcs = List.from(data['pcs']);
    if (pcs.length >= 20) return false;
    _characters.addAll(pcs.map((e) => PlayerCharacter.fromJson(e)));

    if (charCount != pcs.length) {
      for (var map in _maps) {
        map.setLayers(pcs.length + 1);
      }
    }

    return true;
  }
}

class GameMap {
  final int id;
  final dataSocket = WhiteboardDataSocket(WhiteboardData());
  String name;

  WhiteboardData get data => dataSocket.whiteboard;

  GameMap(this.id, this.name, [String encodedData]) {
    if (encodedData != null) {
      data.fromBytes(base64.decode(encodedData));
    }
  }

  GameMap.fromJson(json) : this(json['map'], json['name'], json['data']);

  void setLayers(int layerCount) {
    while (data.layers.length > layerCount) {
      data.layers.removeLast();
    }
    while (data.layers.length < layerCount) {
      data.layers.add(DrawingData());
    }
  }

  Map<String, dynamic> toJson() => {
        'map': id,
        'name': name,
        'data': base64.encode(data.toBytes()),
      };
}

class PlayerCharacter {
  Connection connection;
  String name;
  final CharacterPrefab prefab;

  PlayerCharacter(this.name) : prefab = CharacterPrefab();
  PlayerCharacter.fromJson(Map<String, dynamic> json)
      : name = json['name'],
        prefab = CharacterPrefab()..fromJson(json['prefab'] ?? {});

  Map<String, dynamic> toJson({bool includeStatus = false}) => {
        'name': name,
        'prefab': prefab.toJson(),
        if (includeStatus) 'connected': connection != null,
      };
}

class Scene {
  final List<Movable> movables;
  int get nextMovableId => movables.fold(-1, (v, m) => max<int>(v, m.id)) + 1;
  Point gridOffset;
  int tiles;
  String tileUnit;
  String gridColor;
  num gridAlpha;
  String fogOfWar;

  Scene(Map<String, dynamic> json)
      : movables = List.from(json['movables'] ?? [])
            .map((j) => Movable.create(j['id'], j))
            .toList() {
    applyGrid(json['grid'] ?? {});
    fogOfWar = json['fow'];
  }

  Movable addMovable(Map<String, dynamic> json) {
    var m = Movable.create(nextMovableId, json);
    movables.add(m);
    return m;
  }

  Movable getMovable(int id) {
    return movables.firstWhere((m) => m.id == id, orElse: () => null);
  }

  void removeMovablesOfPrefab(String prefabId) {
    movables.removeWhere((m) => m.prefab == prefabId);
  }

  void removeMovable(int id) {
    movables.removeWhere((m) => m.id == id);
  }

  void applyGrid(Map<String, dynamic> json) {
    gridOffset = parsePoint(json['offset']) ?? Point(0, 0);
    tiles = json['tiles'] ?? 16;
    tileUnit = json['tileUnit'] ?? '5ft';
    gridColor = json['color'] ?? '#000000';
    gridAlpha = json['alpha'] ?? 0.5;
  }

  void applyMovables(Iterable jsons) {
    for (var mj in jsons) {
      var id = mj['id'];
      var m = movables.firstWhere((m) => m.id == id, orElse: () => null);
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
          'tiles': tiles,
          'tileUnit': tileUnit,
          'color': gridColor,
          'alpha': gridAlpha,
        },
        'movables': movables.map((e) => e.toJson()).toList(),
        'fow': fogOfWar,
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
  List<int> accessIds;

  CustomPrefab(this.id, int size)
      : accessIds = [],
        super(size: size);
  CustomPrefab.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        accessIds = List.from(json['access'] ?? []) {
    fromJson(json);
  }

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    name = json['name'];
    accessIds = List.from(json['access'] ?? []);
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'access': accessIds,
        ...super.toJson(),
      };
}

class Movable extends EntityBase {
  final int id;
  final List<int> conds = [];
  String prefab;
  num x;
  num y;

  Movable._(int id, Map<String, dynamic> json)
      : id = id,
        prefab = json['prefab'],
        x = json['x'],
        y = json['y'] {
    fromJson(json);
  }

  static Movable create(int id, Map<String, dynamic> json) {
    if (json['prefab'] == 'e') {
      return EmptyMovable._(id, json);
    }
    return Movable._(id, json);
  }

  @override
  void fromJson(Map<String, dynamic> json) {
    size = json['size'] ?? 0;
    conds.clear();
    conds.addAll(List.from(json['conds'] ?? []));
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'prefab': prefab,
        'x': x,
        'y': y,
        'conds': conds,
        ...super.toJson(),
      };
}

class EmptyMovable extends Movable {
  String label;

  EmptyMovable._(int id, Map<String, dynamic> json) : super._(id, json);

  @override
  void fromJson(Map<String, dynamic> json) {
    size = json['size'] ?? 0;
    label = json['label'] ?? '';
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'prefab': prefab,
        'x': x,
        'y': y,
        'label': label,
        ...super.toJson(),
      };
}
