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
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:random_string/random_string.dart';
import 'package:web_whiteboard/communication/data_socket.dart';
import 'package:web_whiteboard/layers/drawing_data.dart';
import 'package:web_whiteboard/whiteboard_data.dart';

import 'audio.dart';
import 'connections.dart';
import 'controlled_resource.dart';
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

  Future<void> fromJson(Map<String, dynamic> json) async {
    var updateToDynamicLoading = json['games'] != null;
    var owners = <GameMeta, String>{};

    Iterable jGames = updateToDynamicLoading ? json['games'] : json['gameMeta'];
    gameMeta.clear();

    for (var j in jGames) {
      final meta = GameMeta(j['id'], name: j['name']);
      owners[meta] = j['owner'];

      if (updateToDynamicLoading) {
        meta.loadedGame = await Game.fromJson(meta, j);
      }

      gameMeta.add(meta);
    }

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
    await fromJson(json);
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
      return loadedGame = await Game.fromJson(this, json);
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
  static const CURRENT_FILE_VERSION = 2;

  final GameMeta meta;
  Directory get resources => gameResources(meta.id);

  Connection get dm => _connections.firstWhere((c) => meta.owner == c.account,
      orElse: () => null);
  bool get dmOnline => dm != null;
  int get online => _connections.length;
  int get sceneCount => _scenes.length;
  Iterable<PlayerCharacter> get characters => _characters;
  int get prefabCount => _prefabs.length;
  int get mapCount => _maps.length;

  int get _nextCharacterId => _characters.getNextAvailableID((e) => e.id);
  int get _nextPrefabId => _prefabs.getNextAvailableID((e) => e.id);
  int get _nextMapId => _maps.getNextAvailableID((e) => e.id);
  int get _nextSceneId => _scenes.getNextAvailableID((e) => e.id);

  Scene _playingScene;
  Scene get playingScene => _playingScene;

  final _connections = <Connection>[];
  final List<PlayerCharacter> _characters;
  final List<Scene> _scenes;
  final List<CustomPrefab> _prefabs;
  final List<GameMap> _maps;
  final ambience = AmbienceState();

  int _usedDiskSpace = 0;
  int get usedDiskSpace => _usedDiskSpace;

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

  Game.empty(this.meta)
      : _scenes = [],
        _characters = [],
        _prefabs = [],
        _maps = [] {
    _scenes.add(Scene.empty(this, 0));
  }

  void connect(Connection connection, bool join) {
    var pc = _characters.find((e) => e.connection == connection);

    var logId = pc == null ? '-' : String.fromCharCode(lowerAlphaStart + pc.id);
    var logMsg = '${meta.id} ($logId) ';
    print(logMsg + (join ? 'joined' : 'left'));

    notify(a.GAME_CONNECTION, {
      'join': join,
      'pc': pc?.id,
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

  /// Sends GAME_SCENE_PLAY to all connections.
  void playScene(Scene scene, {bool teleportGM = true}) {
    _playingScene = scene;

    for (var c in _connections) {
      if (!teleportGM && c == dm) {
        c.sendAction(a.GAME_SCENE_PLAY, {'sceneID': scene.id});
      } else if (c.scene != scene) {
        c.scene = scene;
        c.sendAction(a.GAME_SCENE_PLAY, scene.toJson(c == dm));
      }
    }
  }

  CustomPrefab addPrefab() {
    var p = CustomPrefab.create(this, _nextPrefabId, 1);
    _prefabs.add(p);
    return p;
  }

  HasInitiativeMod getPrefab(String id) {
    if (id == 'e') return null;

    var isPC = id[0] == 'c';
    if (isPC) {
      final charID = int.parse(id.substring(1));
      return _characters.find((e) => e.id == charID).prefab;
    }

    return getCustomPrefab(int.parse(id));
  }

  CustomPrefab getCustomPrefab(int id) {
    return _prefabs.firstWhere((p) => p.id == id);
  }

  void removePrefab(int id) async {
    final prefab = getCustomPrefab(id);
    if (prefab == null) return null;

    _prefabs.remove(prefab);
    for (var scene in _scenes) {
      scene.removeMovablesOfPrefab('$id');
    }

    await prefab.image.delete();
  }

  Scene getScene(int id) => _scenes.find((scene) => scene.id == id);

  Scene addScene(ControlledResource resource) {
    var scene = Scene.empty(this, _nextSceneId, image: resource)
      ..gridType = playingScene.gridType;
    _scenes.add(scene);
    return scene;
  }

  void removeScene(int sceneID) {
    if (_scenes.length <= 1) throw 'Campaigns must contain at least one scene';

    final scene = getScene(sceneID);
    scene.image.deleteInBackground();

    final sceneIndex = _scenes.indexOf(scene);
    final previousSceneIndex = max(0, sceneIndex - 1);
    final previousScene = _scenes[previousSceneIndex];
    _scenes.remove(scene);

    if (scene == playingScene) {
      // Scene was active playing scene
      playScene(_scenes[previousSceneIndex], teleportGM: scene == dm.scene);
    } else if (scene == dm.scene) {
      // Scene was being edited by GM
      dm.scene = previousScene;
      dm.sendAction(a.GAME_SCENE_GET, previousScene.toJson(true));
    }
  }

  String get readableSizeInMB => (usedDiskSpace / 1000000).toStringAsFixed(2);

  void onResourceAddBytes(int sizeInBytes, {bool notifyGM = true}) {
    _usedDiskSpace += sizeInBytes;

    if (notifyGM) _sendStorageUpdateToGM();
  }

  Future<void> onResourceAdd(File file, {bool notifyGM = true}) async {
    final bytes = await file.length();
    onResourceAddBytes(bytes, notifyGM: notifyGM);
  }

  Future<void> onResourceRemove(File file, {bool notifyGM = true}) async {
    final bytes = await file.length();
    _usedDiskSpace -= bytes;

    if (notifyGM) _sendStorageUpdateToGM();
  }

  void _sendStorageUpdateToGM() {
    if (dmOnline) {
      dm.sendAction(a.GAME_STORAGE_CHANGED, {'used': _usedDiskSpace});
    }
  }

  PlayerCharacter assignPC(int id, Connection c) {
    return _characters.find((e) => e.id == id)..connection = c;
  }

  GameMap addMap(ControlledResource image) {
    final map = GameMap(_nextMapId, '', image: image);
    for (var i = 0; i <= _characters.length; i++) {
      map.data.layers.add(DrawingData());
    }
    _maps.add(map);
    return map;
  }

  GameMap getMap(int id) {
    return _maps.find((m) => m.id == id);
  }

  void removeMap(int id) {
    final map = getMap(id);
    _maps.remove(map);
    map.image.deleteInBackground();
  }

  void handleMapEvent(List<int> bytes, Connection sender) {
    var mapID = bytes[0];
    var map = getMap(mapID);
    if (map.dataSocket.handleEvent(bytes.sublist(1))) {
      for (var conni in _connections) {
        if (conni != sender) {
          conni.send(bytes);
        }
      }
    }
  }

  Future<void> refreshUsedDiskSpace() async {
    _usedDiskSpace = 0;

    if (await resources.exists()) {
      await for (var file in resources.list()) {
        // Skip non-media files
        if (file is File && !file.path.endsWith('.json')) {
          await onResourceAdd(file, notifyGM: false);
        }
      }
    }
  }

  static Future<Game> fromJson(GameMeta meta, Map<String, dynamic> json) async {
    int saveVersion = json['version'] ?? 0;

    final preprocessor = GameFilePreprocessor(json);
    await preprocessor.upgradeFromTo(saveVersion, CURRENT_FILE_VERSION);

    final game = Game._fromJson(meta, json);
    await game.refreshUsedDiskSpace();
    await game.upgradeFromTo(saveVersion, CURRENT_FILE_VERSION);

    return game;
  }

  Game._fromJson(this.meta, Map<String, dynamic> json)
      : _characters = [],
        _scenes = [],
        _prefabs = [],
        _maps = [] {
    _characters.fromJson(json['pcs'], (j) => PlayerCharacter.fromJson(this, j));
    _scenes.fromJson(json['scenes'], (j) => Scene.fromJson(this, j));
    _prefabs.fromJson(json['prefabs'], (j) => CustomPrefab.fromJson(this, j));
    _maps.fromJson(json['maps'], (j) => GameMap.fromJson(this, j));

    _playingScene = getScene(json['scene']);

    if (json['ambience'] != null) {
      ambience.fromJson(json['ambience']);
    }
  }

  Map<String, dynamic> toJson() => {
        'version': CURRENT_FILE_VERSION,
        'scene': playingScene.id,
        'pcs': _characters.map((e) => e.toJson()).toList(),
        'scenes': _scenes.map((e) => e.toJson(true)).toList(),
        'prefabs': _prefabs.map((e) => e.toJson()).toList(),
        'maps': _maps.map((e) => e.toJson()).toList(),
        'ambience': ambience.toJson(includeTracklist: false),
      };

  Map<String, dynamic> toSessionSnippet(Connection c, [int mine]) => {
        'id': meta.id,
        'name': meta.name,
        'scene': playingScene.toJson(meta.owner == c.account),
        'pcs': _characters.map((e) => e.toJson(includeStatus: true)).toList(),
        'maps': _maps.map((e) => e.toJson()).toList(),
        if (mine != null) 'mine': mine,
        'prefabs': _prefabs.map((e) => e.toJson()).toList(),
        'ambience': ambience.toJson(),
        if (meta.owner == c.account)
          'dm': {
            'scenes': _scenes.map((e) => e.toSummaryJson()).toList(),
            'usedStorage': usedDiskSpace,
          },
      };

  Map<String, dynamic> toEditSnippet() => {
        'name': meta.name,
        'pcs': _characters.map((e) => e.toJson(includeStatus: true)).toList(),
        'usedStorage': usedDiskSpace,
      };

  int _getMovableDisplaySize(Movable m) {
    if (m.size == 0) {
      return getPrefab(m.prefab)?.size ?? 1;
    }
    return m.size;
  }

  Future<void> applyChanges(Map<String, dynamic> data) async {
    meta.name = data['name'];

    final Map pcs = data['pcs'];
    if (pcs.length >= playersPerCampaign) throw 'Exceded player limit';

    final previousCharCount = _characters.length;

    for (var pcEntry in pcs.entries) {
      final id = int.parse(pcEntry.key);
      final Map properties = pcEntry.value;

      final pc = _characters.find((e) => e.id == id);

      if (properties == null) {
        _removeCharacter(pc);
      } else {
        await pc.applyCampaignEdits(properties);
      }
    }

    final newPCs = List.from(data['newPCs']);

    for (var properties in newPCs) {
      final pc =
          await PlayerCharacter.create(this, _nextCharacterId, properties);

      _characters.add(pc);
    }

    if (previousCharCount != pcs.length) {
      for (var map in _maps) {
        map.setLayers(pcs.length + 1);
      }
    }
  }

  void _removeCharacter(PlayerCharacter character) {
    final charId = character.id;
    character.avatar.deleteInBackground();

    // Remove obsolete movables
    for (var scene in _scenes) {
      scene.removeMovablesOfPrefab('c$charId');
    }

    _characters.remove(character);
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
      case 2: // Image paths are now referenced directly
        return;
    }
  }
}

class GameFilePreprocessor with Upgradeable {
  final Map data;

  GameFilePreprocessor(this.data);

  void _addResourcePaths(
      Iterable objects, void Function(dynamic obj, int index) modify) {
    objects.forEachIndex(modify);
  }

  @override
  Future<void> applyVersion(int targetVersion) async {
    switch (targetVersion) {
      case 2: // Image paths are now referenced directly
        _addResourcePaths(data['pcs'], (obj, index) {
          obj['id'] = index;
          obj['prefab']['image'] = 'pc$index';
        });
        _addResourcePaths(data['scenes'], (obj, index) {
          obj['id'] = index;
          obj['image'] = 'scene$index';
        });
        _addResourcePaths(
          data['prefabs'],
          (obj, index) => obj['image'] = 'entity$index',
        );
        _addResourcePaths(
          data['maps'],
          (obj, index) => obj['image'] = 'map$index',
        );
    }
  }
}

class GameMap {
  final int id;
  final ControlledResource image;
  final dataSocket = WhiteboardDataSocket(WhiteboardData());
  String name;
  bool shared;

  WhiteboardData get data => dataSocket.whiteboard;

  GameMap(
    this.id,
    this.name, {
    @required this.image,
    this.shared = false,
    String encodedData,
  }) {
    if (encodedData != null) {
      data.fromBytes(base64.decode(encodedData));
    }
  }

  GameMap.fromJson(Game game, json)
      : this(
          json['map'],
          json['name'],
          image: ControlledResource.path(game, json['image']),
          shared: json['shared'] ?? false,
          encodedData: json['data'],
        );

  void update(String name, bool shared) {
    if (name != null) this.name = name;
    if (shared != null) this.shared = shared;
  }

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
        'image': image.filePath,
        'name': name,
        'shared': shared,
        'data': base64.encode(data.toBytes()),
      };
}

class PlayerCharacter {
  final int id;
  final CharacterPrefab prefab;
  Connection connection;

  ControlledResource get avatar => prefab.image;

  PlayerCharacter._(this.id, this.prefab);

  static Future<PlayerCharacter> create(Game game, int id, json) async {
    final prefab = CharacterPrefab(
        '', ControlledResource.path(game, 'asset:default_pc.jpg'));

    final pc = PlayerCharacter._(id, prefab);
    await pc.applyCampaignEdits(json);
    return pc;
  }

  Future<void> applyCampaignEdits(json) async {
    prefab.name = json['name'];

    String avatarData = json['avatar'];
    if (avatarData != null) {
      await avatar.replaceWithData(avatarData);
    }
  }

  PlayerCharacter.fromJson(Game game, Map<String, dynamic> json)
      : id = json['id'],
        prefab = CharacterPrefab(
          json['name'],
          ControlledResource.path(game, json['prefab']['image']),
        )..fromJson(json['prefab'] ?? {}) {
    /// Legacy
    /// Initiative mod was saved in PlayerCharacter instead of mixin
    if (json['mod'] != null) {
      prefab.mod = json['mod'];
    }
  }

  Map<String, dynamic> toJson({bool includeStatus = false}) => {
        'id': id,
        'name': prefab.name,
        'prefab': prefab.toJson(),
        if (includeStatus) 'connected': connection != null,
      };
}

class Scene {
  final int id;
  final ControlledResource image;
  final List<Movable> movables;
  int get nextMovableId => movables.getNextAvailableID((e) => e.id);
  int gridType;
  Point gridOffset;
  Point gridSize;
  int tiles;
  String tileUnit;
  String gridColor;
  num gridAlpha;
  String fogOfWar;
  InitiativeState initiativeState;

  Scene.empty(Game game, this.id, {ControlledResource image})
      : movables = [],
        image = image ?? ControlledResource.empty(game) {
    applyGrid({});
  }

  Scene.fromJson(Game game, Map<String, dynamic> json)
      : id = json['id'],
        movables = List.from(json['movables'] ?? [])
            .map((j) => Movable(j['id'], j))
            .toList(),
        image = ControlledResource.path(game, json['image']) {
    applyGrid(json['grid'] ?? {});
    fogOfWar = json['fow'];
    if (json['initiative'] != null) {
      initiativeState = InitiativeState.fromJson(json['initiative']);
    }
  }

  void tryUseTilesFromAsset() {
    final backgroundFile = image.file;

    if (backgroundFile is SceneAssetFile) {
      tiles = backgroundFile.recommendedTiles;
    }
  }

  Movable addMovable(Map<String, dynamic> json) {
    var m = Movable(nextMovableId, json);
    m.label = generateNewLabel(m, movables);
    movables.add(m);
    return m;
  }

  Movable getMovable(int id) {
    return movables.find((m) => m.id == id);
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
      var m = getMovable(id);
      if (m != null) {
        m.position = parsePoint<double>(mj);
      }
    }
  }

  Map<String, dynamic> toSummaryJson() => {
        'id': id,
        'image': image.filePath,
      };

  Map<String, dynamic> toJson(bool includeDM) => {
        ...toSummaryJson(),
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

mixin HasImage {
  ControlledResource get image;
}

class CharacterPrefab extends EntityBase with HasInitiativeMod, HasImage {
  final ControlledResource _avatar;
  String name;

  @override
  int get jsonFallbackSize => 1;

  @override
  ControlledResource get image => _avatar;

  CharacterPrefab(this.name, ControlledResource avatar) : _avatar = avatar;

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    if (json['name'] != null) name = json['name'];
  }

  @override
  Map<String, dynamic> toJson() => {
        'image': image.filePath,
        ...super.toJson(),
      };
}

class CustomPrefab extends EntityBase with HasInitiativeMod, HasImage {
  final int id;
  final ControlledResource _image;
  String name;
  List<int> accessIds;

  @override
  ControlledResource get image => _image;

  @override
  int get jsonFallbackSize => 1;

  CustomPrefab.create(Game game, this.id, int size)
      : accessIds = [],
        _image = ControlledResource.empty(game),
        super(size: size);
  CustomPrefab.fromJson(Game game, Map<String, dynamic> json)
      : id = json['id'],
        accessIds = List.from(json['access'] ?? []),
        _image = ControlledResource.path(game, json['image']) {
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
        'image': image.filePath,
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
