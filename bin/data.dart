import 'dart:async';
import 'dart:convert';

import 'dart:io';
import 'dart:math';

import 'package:crypt/crypt.dart';
import 'package:dungeonclub/actions.dart' as a;
import 'package:dungeonclub/limits.dart';
import 'package:dungeonclub/models/entity_base.dart';
import 'package:dungeonclub/models/token.dart';
import 'package:dungeonclub/point_json.dart';
import 'package:dungeonclub/session_util.dart';
import 'package:path/path.dart' as path;
import 'package:random_string/random_string.dart';
import 'package:web_whiteboard/communication/data_socket.dart';
import 'package:web_whiteboard/layers/drawing_data.dart';
import 'package:web_whiteboard/whiteboard_data.dart';

import 'audio.dart';
import 'connections.dart';
import 'playing_histogram.dart';
import 'server.dart';
import 'versioning.dart';

class ServerData {
  static final _manualSaveWatch = Stopwatch();
  static final directory = Directory('database');
  static final file = File(path.join(directory.path, 'data.json'));
  static bool _isInitialized = false;

  final histogram = PlayingHistogram(path.join(directory.path, 'histogram'));
  final accounts = <Account>[];
  final gameMeta = <GameMeta>[];
  final Random rng = Random();

  Future<void> init() async {
    await load();
    await histogram.load();
    histogram.startTracking();
    _manualSaveWatch.start();
    _isInitialized = true;
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
        'gameMeta': gameMeta.map((e) => e.toJson()).toList(),
      };

  void fromJson(Map<String, dynamic> json) {
    var updateToDynamicLoading = json['games'] != null;
    var owners = <GameMeta, String>{};

    var jGames = updateToDynamicLoading ? json['games'] : json['gameMeta'];
    gameMeta.clear();
    gameMeta.addAll(List.from(jGames).map((j) {
      var meta = GameMeta(j['id'], name: j['name']);
      owners[meta] = j['owner'];

      if (updateToDynamicLoading) meta.loadedGame = Game.fromJson(meta, j);

      return meta;
    }));
    print('Loaded ${gameMeta.length} game meta entries');

    accounts.clear();
    accounts
        .addAll(List.from(json['accounts']).map((j) => Account.fromJson(j)));
    print('Loaded ${accounts.length} accounts');

    owners.forEach((game, ownerEmail) {
      game.owner = data.getAccount(ownerEmail, alreadyEncrypted: true);
    });

    if (updateToDynamicLoading) {
      print('Updated to dynamic game loading system!');
    }
  }

  Future<void> save() async {
    if (!_isInitialized) return print('Not initialized, skipped save.');

    var json = JsonEncoder.withIndent(' ').convert(toJson());
    // print(json);
    await file.writeAsString(json);
    await histogram.save();

    for (var meta in gameMeta) {
      if (meta.isLoaded) {
        print('Saving ' + meta.id);
        await meta._save();
        if (meta.loadedGame._connections.isEmpty) {
          print('Closing unused ' + meta.id);
          meta.loadedGame = null;
        }
      }
    }
    print('Saved!');
  }

  Future<void> load() async {
    if (!await file.exists()) {
      await file.create(recursive: true);
      return file.writeAsString('{}');
    }

    var s = await file.readAsString();
    var json = jsonDecode(s);
    fromJson(json);
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

class GameMeta {
  final String id;
  Account owner;
  String name;
  Game loadedGame;

  File get dataFile => File(path.join(gameResources(id).path, 'data.json'));
  bool get isLoaded => loadedGame != null;

  GameMeta(this.id, {this.owner, this.name});
  GameMeta.create(this.owner) : id = _generateId();

  static String _generateId() {
    String id;
    do {
      id = randomAlphaNumeric(10);
    } while (data.gameMeta.any((g) => g.id == id));
    return id;
  }

  Future<Game> open() async {
    if (loadedGame != null) return loadedGame;

    if (await dataFile.exists()) {
      print('Opening $id');
      var json = jsonDecode(await dataFile.readAsString());
      return loadedGame = Game.fromJson(this, json);
    }

    return null;
  }

  Future<void> _save({bool close = false}) async {
    if (loadedGame != null) {
      var json = jsonEncode(loadedGame.toJson());
      if (close) loadedGame = null;
      await dataFile.create(recursive: true);
      await dataFile.writeAsString(json);
    }
  }

  Future<void> close() async {
    if (loadedGame != null) {
      print('Closing $id');
      return _save(close: true);
    }
  }

  Future<void> delete() async {
    var resources = gameResources(id);
    if (await resources.exists()) {
      await resources.delete(recursive: true);
    }
    data.gameMeta.remove(this);
    owner.enteredGames.remove(this);
  }

  Map<String, dynamic> toSnippet(Account acc) => {
        'id': id,
        'name': name,
        'mine': acc == owner,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'owner': owner.encryptedEmail.toString(),
      };
}

class Account {
  final Crypt encryptedEmail;
  Crypt encryptedPassword;

  var enteredGames = <GameMeta>[];
  Iterable<GameMeta> get ownedGames =>
      enteredGames.where((g) => g.owner == this);

  Account(String email, String password)
      : encryptedEmail = Crypt.sha256(email),
        encryptedPassword = Crypt.sha256(password);

  bool ownsGame(String gameId) {
    return enteredGames.any((g) => g.id == gameId && g.owner == this);
  }

  void setPassword(String password) {
    encryptedPassword = Crypt.sha256(password);
  }

  Account.fromJson(Map<String, dynamic> json)
      : encryptedEmail = Crypt(json['email']),
        encryptedPassword = Crypt(json['password']),
        enteredGames = List.from(json['games'])
            .map((id) => data.gameMeta.firstWhere(
                  (g) => g.id == id,
                  orElse: () => null,
                ))
            .where((g) => g != null)
            .toList();

  Future<void> delete() async {
    for (var game in ownedGames.toList()) {
      await game.delete();
    }
    data.accounts.remove(this);
  }

  Map<String, dynamic> toJson() => {
        'email': encryptedEmail.toString(),
        'password': encryptedPassword.toString(),
        'games': enteredGames.map((g) => g.id).toList(),
      };

  Map<String, dynamic> toSnippet() => {
        'games': enteredGames.map((g) => g.toSnippet(this)).toList(),
      };
}

Directory gameResources(String id) =>
    Directory(path.join(ServerData.directory.path, 'games', id));

class Game with Upgradeable {
  static const CURRENT_FILE_VERSION = 1;

  final GameMeta meta;
  Directory get resources => gameResources(meta.id);

  Connection get dm => _connections.firstWhere((c) => meta.owner == c.account,
      orElse: () => null);
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
  final ambience = AmbienceState();
  int playingSceneId = 0;

  void notify(String action, Map<String, dynamic> params,
      {Connection exclude, bool allScenes = false}) {
    for (var c in _connections) {
      if (exclude == null ||
          (c != exclude && (allScenes || c.scene == exclude.scene))) {
        c.sendAction(action, params);
      }
    }
  }

  void notifyBinary(List<int> data,
      {Connection exclude, bool allScenes = false}) {
    for (var c in _connections) {
      if (exclude == null ||
          (c != exclude && (allScenes || c.scene == exclude.scene))) {
        c.send(data);
      }
    }
  }

  Future<File> getFile(String filePath) async {
    if (!await resources.exists()) {
      await resources.create(recursive: true);
    }
    return File(path.join(resources.path, filePath));
  }

  Game(this.meta)
      : _scenes = [Scene({})],
        _characters = [],
        _prefabs = [],
        _maps = [];

  void connect(Connection connection, bool join) {
    var pc = _characters.firstWhere(
      (e) => e.connection == connection,
      orElse: () => null,
    );

    var pcId = _characters.indexOf(pc);
    var logId = pcId < 0 ? '-' : String.fromCharCode(lowerAlphaStart + pcId);
    var logMsg = '${meta.id} ($logId) ';
    print(logMsg + (join ? 'joined' : 'left'));

    notify(a.GAME_CONNECTION, {
      'join': join,
      'pc': pcId,
    });

    if (!join) {
      pc?.connection = null;
      _connections.remove(connection);

      if (_connections.isEmpty) {
        meta.close();
      }
    } else {
      _connections.add(connection);
      connection.logPrefix = logMsg;
    }
  }

  void playScene(int id) {
    playingSceneId = id;
    var scene = playingScene;
    for (var c in _connections) {
      c.scene = scene;
    }
  }

  CustomPrefab addPrefab() {
    var p = CustomPrefab(_nextPrefabId, 1);
    _prefabs.add(p);
    return p;
  }

  HasInitiativeMod getPrefab(String id) {
    if (id == 'e') return null;

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

  Scene getScene(int id) =>
      (id != null && id < _scenes.length) ? _scenes[id] : null;

  Scene addScene() {
    var scene = Scene({})..gridType = playingScene.gridType;
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

  void updateMap(int id, String name, bool shared) {
    var map = _maps.firstWhere((m) => m.id == id);
    if (name != null) map.name = name;
    if (shared != null) map.shared = shared;
  }

  void removeMap(int id) async {
    _maps.removeWhere((m) => m.id == id);
    var file = await getFile('${a.IMAGE_TYPE_MAP}$id');
    await file.delete();
  }

  void handleMapEvent(List<int> bytes, Connection sender) {
    var mapIndex = bytes[0];
    var map = _maps.firstWhere((m) => m.id == mapIndex);
    if (map.dataSocket.handleEvent(bytes.sublist(1))) {
      for (var conni in _connections) {
        if (conni != sender) {
          conni.send(bytes);
        }
      }
    }
  }

  Game.fromJson(this.meta, Map<String, dynamic> json)
      : playingSceneId = json['scene'] ?? 0,
        _scenes = List.from(json['scenes']).map((e) => Scene(e)).toList(),
        _characters = List.from(json['pcs'])
            .map((j) => PlayerCharacter.fromJson(j))
            .toList(),
        _prefabs = List.from(json['prefabs'] ?? [])
            .map((j) => CustomPrefab.fromJson(j))
            .toList(),
        _maps = List.from(json['maps'] ?? [])
            .map((j) => GameMap.fromJson(j))
            .toList() {
    if (json['ambience'] != null) {
      ambience.fromJson(json['ambience']);
    }

    int saveVersion = json['version'] ?? 0;
    upgradeFromTo(saveVersion, CURRENT_FILE_VERSION);
  }

  Map<String, dynamic> toJson() => {
        'version': CURRENT_FILE_VERSION,
        'scene': playingSceneId,
        'pcs': _characters.map((e) => e.toJson()).toList(),
        'scenes': _scenes.map((e) => e.toJson(true)).toList(),
        'prefabs': _prefabs.map((e) => e.toJson()).toList(),
        'maps': _maps.map((e) => e.toJson()).toList(),
        'ambience': ambience.toJson(includeTracklist: false),
      };

  Map<String, dynamic> toSessionSnippet(Connection c, [int mine]) => {
        'id': meta.id,
        'name': meta.name,
        'sceneId': playingSceneId,
        'scene': playingScene.toJson(meta.owner == c.account),
        'pcs': _characters.map((e) => e.toJson(includeStatus: true)).toList(),
        'maps': _maps.map((e) => e.toJson()).toList(),
        if (mine != null) 'mine': mine,
        'prefabs': _prefabs.map((e) => e.toJson()).toList(),
        'ambience': ambience.toJson(),
        if (meta.owner == c.account) 'dm': {'scenes': _scenes.length},
      };

  Map<String, dynamic> toEditSnippet() => {
        'name': meta.name,
        'pcs': _characters.map((e) => e.toJson(includeStatus: true)).toList(),
      };

  int _getMovableDisplaySize(Movable m) {
    if (m.size == 0) {
      return getPrefab(m.prefab)?.size ?? 1;
    }
    return m.size;
  }

  @override
  Future<void> applyVersion(int targetVersion) async {
    switch (targetVersion) {
      case 1: // Tokens are now anchored to their center instead of top left
        for (var scene in _scenes) {
          for (var mv in scene.movables) {
            final off = 0.5 * _getMovableDisplaySize(mv);
            mv.position += Point(off, off);
          }
        }
        return;
    }
  }

  Future<bool> applyChanges(Map<String, dynamic> data) async {
    meta.name = data['name'];

    var pcs = List.from(data['pcs']);
    if (pcs.length >= playersPerCampaign) return false;

    var removes = List<int>.from(data['removes']);
    var previousCharCount = _characters.length;
    var keptCharCount = previousCharCount - removes.length;
    await _removeCharacters(removes);

    for (var i = 0; i < pcs.length; i++) {
      if (i < keptCharCount) {
        _characters[i].prefab.name = pcs[i]['name'];
      } else {
        _characters.add(PlayerCharacter.fromJson(pcs[i]));
      }
    }

    // Remove obsolete character files
    for (var i = keptCharCount; i < previousCharCount; i++) {
      var charFile = await getFile('${a.IMAGE_TYPE_PC}$i');
      if (await charFile.exists()) await charFile.delete();
    }

    if (previousCharCount != pcs.length) {
      for (var map in _maps) {
        map.setLayers(pcs.length + 1);
      }
    }

    return true;
  }

  Future<void> _removeCharacters(Iterable<int> indices) async {
    var charIdMap = <int, int>{};
    var change = 0;
    var charCount = _characters.length;

    for (var charId = 0; charId < charCount; charId++) {
      if (indices.contains(charId)) {
        _characters.removeAt(charId + change);
        change--;
        // Remove obsolete movables
        _removeCharacterMovables(charId);
      } else if (change != 0) {
        charIdMap[charId] = charId + change;
      }
    }

    // Change file names for characters that were kept
    for (var idPrevious in charIdMap.keys) {
      var idNext = charIdMap[idPrevious];

      var prefabIdPrevious = 'c$idPrevious';
      var prefabIdNext = 'c$idNext';

      for (var scene in _scenes) {
        for (var mov in scene.movables) {
          if (mov.prefab == prefabIdPrevious) {
            mov.prefab = prefabIdNext;
          }
        }
      }

      var file = await getFile('${a.IMAGE_TYPE_PC}$idPrevious');
      if (await file.exists()) {
        var nextFile = await getFile('${a.IMAGE_TYPE_PC}$idNext');
        print('Renaming ${file.path} to ${nextFile.path}');
        await file.rename(nextFile.path);
      }
    }
  }

  void _removeCharacterMovables(int charId) {
    for (var scene in _scenes) {
      scene.removeMovablesOfPrefab('c$charId');
    }
  }
}

class GameMap {
  final int id;
  final dataSocket = WhiteboardDataSocket(WhiteboardData());
  String name;
  bool shared;

  WhiteboardData get data => dataSocket.whiteboard;

  GameMap(this.id, this.name, [this.shared = false, String encodedData]) {
    if (encodedData != null) {
      data.fromBytes(base64.decode(encodedData));
    }
  }

  GameMap.fromJson(json)
      : this(json['map'], json['name'], json['shared'] ?? false, json['data']);

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
        'shared': shared,
        'data': base64.encode(data.toBytes()),
      };
}

class PlayerCharacter {
  final CharacterPrefab prefab;
  Connection connection;

  PlayerCharacter(String name) : prefab = CharacterPrefab(name);
  PlayerCharacter.fromJson(Map<String, dynamic> json)
      : prefab = CharacterPrefab(json['name'])..fromJson(json['prefab'] ?? {}) {
    /// Legacy
    /// Initiative mod was saved in PlayerCharacter instead of mixin
    if (json['mod'] != null) {
      prefab.mod = json['mod'];
    }
  }

  Map<String, dynamic> toJson({bool includeStatus = false}) => {
        'name': prefab.name,
        'prefab': prefab.toJson(),
        if (includeStatus) 'connected': connection != null,
      };
}

class Scene {
  final List<Movable> movables;
  int get nextMovableId => movables.fold(-1, (v, m) => max<int>(v, m.id)) + 1;
  int gridType;
  Point gridOffset;
  Point gridSize;
  int tiles;
  String tileUnit;
  String gridColor;
  num gridAlpha;
  String fogOfWar;
  InitiativeState initiativeState;

  Scene(Map<String, dynamic> json)
      : movables = List.from(json['movables'] ?? [])
            .map((j) => Movable(j['id'], j))
            .toList() {
    applyGrid(json['grid'] ?? {});
    fogOfWar = json['fow'];
    if (json['initiative'] != null) {
      initiativeState = InitiativeState.fromJson(json['initiative']);
    }
  }

  Movable addMovable(Map<String, dynamic> json) {
    var m = Movable(nextMovableId, json);
    m.label = generateNewLabel(m, movables);
    movables.add(m);
    return m;
  }

  Movable getMovable(int id) {
    return movables.firstWhere((m) => m.id == id, orElse: () => null);
  }

  void removeMovablesOfPrefab(String prefabId) {
    movables.removeWhere((m) => m.prefab == prefabId);
    cleanInitiativeState();
  }

  void removeMovable(int id) {
    movables.removeWhere((m) => m.id == id);
    cleanInitiativeState();
  }

  /// Removes initiatives of movables that don't exist anymore.
  void cleanInitiativeState() {
    initiativeState?.initiatives
        ?.retainWhere((ini) => movables.any((m) => m.id == ini.movableId));
  }

  void applyGrid(Map<String, dynamic> json) {
    gridType = json['type'] ?? a.GRID_SQUARE;
    gridOffset = parsePoint(json['offset']) ?? Point(0, 0);
    gridSize = parsePoint(json['size']);
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
        m.position = parsePoint<double>(mj);
      }
    }
  }

  Map<String, dynamic> toJson(bool includeDM) => {
        'grid': {
          'type': gridType,
          'offset': writePoint(gridOffset),
          'size': writePoint(gridSize),
          'tiles': tiles,
          'tileUnit': tileUnit,
          'color': gridColor,
          'alpha': gridAlpha,
        },
        'movables': movables.map((e) => e.toJson()).toList(),
        'fow': fogOfWar,
        'initiative': initiativeState?.toJson(includeDM),
      };
}

class CharacterPrefab extends EntityBase with HasInitiativeMod {
  String name;

  @override
  int get jsonFallbackSize => 1;

  CharacterPrefab(this.name);

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    if (json['name'] != null) name = json['name'];
  }
}

class CustomPrefab extends EntityBase with HasInitiativeMod {
  final int id;
  String name;
  List<int> accessIds;

  @override
  int get jsonFallbackSize => 1;

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

class Movable extends EntityBase with TokenModel {
  final int _id;
  String prefab;

  @override
  int get id => _id;

  @override
  String get prefabId => prefab;

  Movable(int id, Map<String, dynamic> json)
      : _id = id,
        prefab = json['prefab'] {
    fromJson(json);
  }

  @override
  Map<String, dynamic> toJson() => {
        'prefab': prefab,
        ...super.toJson(),
      };
}

class InitiativeState {
  final List<Initiative> initiatives;

  InitiativeState(this.initiatives);
  InitiativeState.fromJson(json)
      : this((json as Iterable).map((j) => Initiative.fromJson(j)).toList());

  List toJson(bool isDM) => initiatives
      .where((ini) => (!ini.dmOnly || isDM))
      .map((e) => e.toJson())
      .toList();
}

class Initiative {
  final int movableId;
  final int roll;
  bool dmOnly;
  int mod;

  Initiative(this.movableId, this.roll, this.mod, this.dmOnly);
  Initiative.fromJson(json)
      : this(json['id'], json['roll'], json['mod'], json['dm']);

  Map<String, dynamic> toJson({bool includeDm = true}) => {
        'id': movableId,
        'roll': roll,
        'mod': mod,
        if (includeDm) 'dm': dmOnly,
      };
}
