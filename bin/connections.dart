import 'dart:async';

import 'package:dungeonclub/actions.dart' as a;
import 'package:dungeonclub/comms.dart';
import 'package:dungeonclub/dice_parser.dart';
import 'package:dungeonclub/iterable_extension.dart';
import 'package:dungeonclub/limits.dart';
import 'package:dungeonclub/point_json.dart';
import 'package:random_string/random_string.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'asset_provider.dart';
import 'audio.dart';
import 'controlled_resource.dart';
import 'data.dart';
import 'mail.dart';
import 'server.dart';

const sendPings = false;

final connections = <Connection>[];
final activationCodes = <Connection, String>{};
final resets = <Connection, PasswordReset>{};
final tokenAccounts = <String, Account>{};

void onConnect(WebSocketChannel ws) {
  print('New connection!');
  connections.add(Connection(ws));
}

class PasswordReset {
  final String email;
  final String password;
  final String code;

  PasswordReset(this.email, this.password, this.code);
}

class Connection extends Socket {
  final WebSocketChannel ws;
  final Stream broadcastStream;
  Timer? _pingTimer;
  Game? _game;
  String logPrefix = '';

  Scene? scene;

  Account? _account;
  Account? get account => _account;

  Connection(this.ws) : broadcastStream = ws.stream.asBroadcastStream() {
    listen(
      onDone: () {
        print('Lost connection (${ws.closeCode})');
        if (ws.closeCode != 1001 && (ws.closeReason?.isNotEmpty ?? false)) {
          print(ws.closeReason);
        }
        activationCodes.remove(this);
        resets.remove(this);
        _game?.connect(this, false);
        connections.remove(this);
        _pingTimer?.cancel();
      },
      onError: (err) {
        print('ws error');
        print(err);
        print(ws.closeCode);
        print(ws.closeReason);
      },
    );

    if (sendPings) {
      _pingTimer = Timer.periodic(wsPing, (timer) => send([99]));
    }

    if (maintainer.shutdownTime != null) {
      sendAction(a.MAINTENANCE, maintainer.jsonEntry);
    }
  }

  bool get connectionClosed => ws.closeCode != null;

  @override
  Stream get messageStream => broadcastStream;

  @override
  Future<void> send(data) async => ws.sink.add(data);

  @override
  String modifyLog(String message) => '$logPrefix$message';

  @override
  Future handleAction(
    String action, [
    Map<String, dynamic>? params,
  ]) async {
    params ??= {};

    switch (action) {
      case a.ACCOUNT_REGISTER:
        String email = params['email'];

        if (data.getAccount(email) != null) {
          return 'Email address already in use!';
        }

        _account = Account(email, params['password']);
        final code = generateCode();
        activationCodes[this] = code;
        return await sendVerifyCreationMail(email, code)
            ? true
            : 'Email could not be sent.';

      case a.ACCOUNT_ACTIVATE:
        final actualCode = activationCodes[this];
        String code = params['code'];

        if (actualCode == null || code != actualCode) {
          throw 'Invalid activation code';
        }

        activationCodes.remove(this);
        print('New account activated!');
        data.accounts.add(_account!);
        return _account!.toSnippet();

      case a.ACCOUNT_LOGIN:
        String? email = params['email'];
        String? password = params['password'];
        String? token = params['token'];
        bool remember = params['remember'] ?? false;

        if (email == null || password == null) {
          if (token == null || tokenAccounts[token] == null) {
            return null;
          }

          return loginAccount(tokenAccounts[token]!);
        }

        return login(params['email'], params['password'],
            provideToken: remember);

      case a.ACCOUNT_RESET_PASSWORD:
        String email = params['email'];
        String password = params['password'];

        if (data.getAccount(email) == null) {
          return 'No account connected to this email address found!';
        }

        final code = generateCode();
        resets[this] = PasswordReset(email, password, code);
        return await sendResetPasswordMail(email, code);

      case a.ACCOUNT_RESET_PASSWORD_ACTIVATE:
        final reset = resets[this];
        String code = params['code'];

        if (reset == null || code != reset.code) {
          throw 'Invalid activation code';
        }

        final acc = data.getAccount(reset.email)!;

        acc.setPassword(reset.password);

        resets.remove(this);
        tokenAccounts.removeWhere((s, a) => a == acc);
        print('Password changed!');
        return loginAccount(acc);

      case a.GAME_CREATE_NEW:
        _requireLogin();

        if (account!.ownedGames.length > campaignsPerAccount) {
          throw RangeError('Campaign limit reached');
        }

        final createdMeta = GameMeta.create(account!);
        final createdGame = Game.empty(createdMeta);

        await createdGame.applyChanges(params['data']);

        _game = createdGame..connect(this, true);
        scene = _game!.playingScene;
        data.gameMeta.add(createdMeta..loadedGame = createdGame);
        account!.enteredGames.add(createdMeta);

        final assetPath = await resolveIndexedAsset(
          'asset/scene/',
          pickRandom: true,
        );

        final asset = AssetFile.tryAsSceneAsset(assetPath);
        scene!.image.replaceWithFile(asset);
        scene!.tryUseTilesFromAsset();

        return _game!.toSessionSnippet(this);

      case a.GAME_EDIT:
        _requireLogin();

        final gameId = params['id'];
        final meta = account!.ownedGames.find((g) => g.id == gameId);

        if (meta == null) throw 'Access denied!';

        final game = await meta.open();

        final data = params['data'];
        if (data != null) {
          // User wants to save changes.
          game.notify(
            a.GAME_KICK,
            {
              'reason': '''Your GM updated the campaign settings.
                To reflect all changes, please join again.''',
            },
            allScenes: true,
          );
          await game.applyChanges(data);

          await meta.close();
          return true;
        }

        return game.toEditSnippet();

      case a.GAME_DELETE:
        _requireLogin();

        final gameId = params['id'];
        final game = account!.ownedGames.find((g) => g.id == gameId);

        if (game == null) return 'Access denied!';

        await game.delete();

        return true;

      case a.GAME_JOIN:
        String id = params['id'];

        final meta = data.gameMeta.find((g) => g.id == id);

        if (meta != null) {
          var game = meta.loadedGame;

          int? myId;
          if (meta.owner != account) {
            if (game == null || !game.dmOnline) {
              return 'Your GM is not online!';
            }

            String name = params['name'];
            myId = await game.dm!.request(a.GAME_JOIN_REQUEST, {'name': name});

            if (myId == null) {
              return "You're not allowed to enter!";
            }

            if (connectionClosed) {
              return game.dm!.sendAction(a.GAME_CONNECTION, {
                'cancelled': true,
              });
            }

            game.assignPC(myId, this);
          } else {
            game = await meta.open();
          }
          _game = game..connect(this, true);
          scene = game.playingScene;
          return game.toSessionSnippet(this, myId);
        }
        return 'Game "$id" not found!';

      case a.GAME_KICK:
        _requireOwnerOfSession();

        int pc = params['pc'];

        final connection = _game!.characters.elementAt(pc).connection!;
        _game!.connect(connection, false); // Ensure disconnect
        connection._game = null;

        return connection.sendAction(action, {
          'reason': '''Your GM decided it's time for you to leave.''',
        });

      case a.GAME_PREFAB_CREATE:
        _requireOwnerOfSession();

        if (_game!.prefabCount >= prefabsPerCampaign) {
          throw RangeError('Prefab limit reached');
        }

        String data = params['data'];

        final prefab = _game!.addPrefab();
        await prefab.image.replaceWithData(data);

        final response = prefab.toJson();
        notifyOthers(action, response, true);
        return response;

      case a.GAME_PREFAB_UPDATE:
        _requireOwnerOfSession();

        String pid = params['prefab'];
        final data = params['data'];

        final prefab = _game!.getPrefab(pid);
        if (prefab == null) {
          throw 'Unable to find prefab with ID $pid';
        }

        if (data != null) {
          // Update prefab image
          final resource = (prefab as HasImage).image;
          await resource.replaceWithData(data);

          final response = {'image': resource.filePath};
          final responseWithID = {'prefab': pid, ...response};

          notifyOthers(action, responseWithID, true);
          return response;
        }

        // Update prefab properties
        prefab.fromJson(params);

        notifyOthers(action, params, true);
        return params;

      case a.GAME_PREFAB_REMOVE:
        _requireOwnerOfSession();

        final id = int.parse(params['prefab']);
        _game!.removePrefab(id);
        return notifyOthers(action, params, true);

      case a.GAME_MOVABLE_CREATE:
        _requireOwnerOfSession();

        if (scene != null && scene!.movables.length < movablesPerScene) {
          final m = scene!.addMovable(params);

          notifyOthers(action, {
            'id': m.id,
            'prefab': m.prefab,
            ...writePoint(m.position),
          });
          return m.id;
        }
        return null;

      case a.GAME_MOVABLE_CREATE_ADVANCED:
        if (scene != null) {
          List source = params['movables'];
          if (scene!.movables.length + source.length <= movablesPerScene) {
            var dest = source.map((src) => scene!.addMovable(src)).toList();

            notifyOthers(action, {'movables': dest});
            return dest.map((m) => m.id).toList();
          }
        }
        return null;

      case a.GAME_MOVABLE_MOVE:
        List? ids = params['movables'];
        final delta = parsePoint<double>(params);

        if (ids == null || delta == null || scene == null) return null;

        for (int movableId in ids) {
          scene!.getMovable(movableId)?.position += delta;
        }

        return notifyOthers(action, params);

      case a.GAME_MOVABLE_SNAP:
        if (scene == null) return null;

        for (var jm in params['movables']) {
          final m = scene!.getMovable(jm['id']);
          m?.handleSnapEvent(jm);
        }

        return notifyOthers(action, params);

      case a.GAME_MOVABLE_UPDATE:
        var changes = params['changes'];
        for (var change in changes) {
          scene?.getMovable(change['movable'])?.fromJson(change);
        }
        return notifyOthers(action, params);

      case a.GAME_MOVABLE_REMOVE:
        List ids = params['movables'];

        for (int id in ids) {
          scene?.removeMovable(id);
        }
        return notifyOthers(action, params);

      case a.GAME_SCENE_UPDATE:
        _requireOwnerOfSession();

        final grid = params['grid'];
        if (grid != null) {
          scene!.applyGrid(grid);
          scene!.applyMovables(params['movables']);
          return notifyOthers(action, params);
        }

        String img = params['data'];

        // Update scene image
        await scene!.image.replaceWithData(img);

        final response = scene!.image.toJsonResponse()!;
        _game!.notify(a.GAME_SCENE_UPDATE, response, exclude: this);
        return response;

      case a.GAME_SCENE_GET:
        _requireOwnerOfSession();

        int sceneID = params['id'];

        final scene = _game!.getScene(sceneID);

        if (scene == null) {
          throw "Scene with ID $sceneID doesn't exist";
        }

        this.scene = scene;
        return scene.toJson(true);

      case a.GAME_SCENE_PLAY:
        _requireOwnerOfSession();

        int sceneID = params['id'];
        final scene = _game!.getScene(sceneID);

        if (scene == null) {
          throw "Scene with ID $sceneID doesn't exist";
        }

        _game!.playScene(scene);
        return;

      case a.GAME_SCENE_ADD:
        _requireOwnerOfSession();

        if (_game!.sceneCount >= scenesPerCampaign) {
          throw RangeError('Scene limit reached');
        }

        String background = params['data'];
        final resource = await ControlledResource.withData(_game!, background);

        final newScene = _game!.addScene(resource);
        newScene.tryUseTilesFromAsset();

        scene = newScene;
        return newScene.toJson(true);

      case a.GAME_SCENE_REMOVE:
        _requireOwnerOfSession();

        int id = params['id'];

        _game!.removeScene(id);
        return;

      case a.GAME_SCENE_FOG_OF_WAR:
        _requireOwnerOfSession();

        String data = params['data'];

        scene!.fogOfWar = data;
        _game!.notify(action, params, exclude: this);
        return true;

      case a.GAME_ROLL_DICE:
        _requireInSession();

        var combo = RollCombo.fromJson(params);
        int? charId = params['id'];
        bool public = params['public'] ?? true;

        combo.rollAll();

        final results = {
          ...combo.toJson(),
          'id': charId,
        };

        if (public) {
          _game!.notify(action, results, exclude: this, allScenes: true);
        }
        return results;

      case a.GAME_MAP_CREATE:
        _requireOwnerOfSession();

        if (_game!.mapCount >= mapsPerCampaign) {
          throw RangeError('Map limit reached');
        }

        final image = params['data'];
        final resource = await ControlledResource.withData(_game!, image);

        final map = _game!.addMap(resource);
        final response = {
          'map': map.id,
          'image': resource.filePath,
        };

        _game!.notify(action, response, exclude: this, allScenes: true);
        return response;

      case a.GAME_MAP_UPDATE:
        _requireOwnerOfSession();

        int id = params['map'];
        String? name = params['name'];
        bool? shared = params['shared'];

        final map = _game!.getMap(id);
        if (map == null) {
          throw 'Invalid map ID $id';
        }

        if (name != null || shared != null) {
          // Update map properties
          map.update(name, shared);
          _game!.notify(action, params, exclude: this, allScenes: true);
          return true;
        }

        // Update map image
        await map.image.replaceWithData(params['data']);

        final response = {
          'map': id,
          'image': map.image.filePath,
        };

        _game!.notify(action, response, exclude: this, allScenes: true);
        return response;

      case a.GAME_MAP_REMOVE:
        _requireOwnerOfSession();

        int id = params['map'];

        _game!.removeMap(id);
        _game!.notify(action, {'map': id}, exclude: this, allScenes: true);
        return;

      case a.GAME_PING:
        _requireInSession();

        _game!.notify(action, params, exclude: this);
        return;

      case a.GAME_CHAT:
        _requireInSession();

        _game!.notify(action, params, exclude: this, allScenes: true);
        return;

      case a.FEEDBACK:
        String type = params['type'];
        String content = params['content'];

        if (!Feedback.validTypes.contains(type)) {
          throw 'Invalid feedback type';
        }

        pendingFeedback.add(Feedback(
          type,
          content,
          account?.encryptedEmail.toString(),
          _game?.meta.id,
        ));
        return true;

      case a.GAME_UPDATE_INITIATIVE:
        _requireOwnerOfSession();

        int id = params['id'];
        int mod = params['mod'];
        bool? dmOnly = params['dm'];

        final initiative = scene!.initiativeState!.initiatives
            .firstWhere((ini) => ini.movableId == id);
        initiative.mod = mod;

        final movable = scene!.getMovable(id);
        if (movable == null) {
          throw 'Invalid movable ID $id';
        }

        final prefab = _game!.getPrefab(movable.prefab);
        prefab?.mod = mod;

        if (dmOnly != null) {
          if (initiative.dmOnly != dmOnly) {
            initiative.dmOnly = dmOnly;
            return _game!.notify(
              dmOnly ? a.GAME_REMOVE_INITIATIVE : a.GAME_ADD_INITIATIVE,
              dmOnly ? {'id': id} : initiative.toJson(includeDm: false),
              exclude: this,
              allScenes: true,
            );
          }
        }

        if (initiative.dmOnly) return;

        return notifyOthers(action, params);

      case a.GAME_ROLL_INITIATIVE:
        _requireOwnerOfSession();

        scene!.initiativeState = InitiativeState([]);
        return notifyOthers(action, params);

      case a.GAME_ADD_INITIATIVE:
        _requireInSession();

        int id = params['id'];
        int roll = params['roll'];
        bool dm = params['dm'];

        final movable = scene!.getMovable(id);
        if (movable == null) {
          throw 'Invalid movable ID $id';
        }

        final prefab = _game!.getPrefab(movable.prefab);
        final mod = prefab?.mod ?? 0;

        scene!.initiativeState!.initiatives.add(Initiative(id, roll, mod, dm));
        if (dm) return;

        return notifyOthers(action, params);

      case a.GAME_REMOVE_INITIATIVE:
        _requireOwnerOfSession();

        int id = params['id'];
        scene!.initiativeState!.initiatives
            .removeWhere((i) => i.movableId == id);

        return notifyOthers(action, params);

      case a.GAME_CLEAR_INITIATIVE:
        _requireOwnerOfSession();

        scene!.initiativeState = null;
        return notifyOthers(action, params);

      case a.GAME_REROLL_INITIATIVE:
        _requireOwnerOfSession();
        return notifyOthers(action, params);

      case a.GAME_MUSIC_PLAYLIST:
        String? playlistName = params['playlist'];

        if (_game == null && playlistName == null) {
          // User is in a demo session and stops the audio player,
          // no backend handling needed.
          return null;
        }

        if (playlistName == null) {
          _game!.ambience.playlistName = null;
          _game!.ambience.list = null;
          _game!.notify(action, {}, exclude: this, allScenes: true);
          return;
        }

        final playlist = collection.playlists.find(
          (pl) => pl.title == playlistName,
        );

        if (playlist == null) {
          throw 'Invalid playlist name $playlistName';
        }

        final tracklist = playlist.toTracklist(shuffle: true);
        _game?.ambience.playlistName = playlist.title;
        _game?.ambience.list = tracklist;

        final response = tracklist.toJson();
        _game?.notify(action, response, exclude: this, allScenes: true);

        return response;

      case a.GAME_MUSIC_SKIP:
        _requireInSession();

        _game!.ambience.list?.fromSyncJson(params);
        return notifyOthers(action, params);

      case a.GAME_MUSIC_AMBIENCE:
        _requireInSession();

        _game!.ambience.ambienceFromJson(params);
        return notifyOthers(action, params);

      case 'manualSave':
        return data.manualSave();
    }
  }

  void _requireLogin() {
    if (account == null) {
      throw 'You must be logged in';
    }
  }

  void _requireInSession() {
    if (_game == null || scene == null) {
      throw 'You must be in a running session';
    }
  }

  void _requireOwnerOfSession() {
    _requireInSession();
    _requireLogin();

    if (_game!.meta.owner != account) {
      throw 'You must be DM';
    }
  }

  static String generateCode() {
    var len = 5;
    var alphaLen = randomBetween(0, len);
    var alpha = randomString(
      alphaLen,
      from: upperAlphaStart,
      to: upperAlphaEnd,
    ).replaceAll(RegExp(r'O|I|S'), '');

    var numeric = randomString(
      len - alpha.length,
      from: numericStart + 1,
      to: numericEnd,
    );
    return randomMerge(alpha, numeric);
  }

  void notifyOthers(
    String action, [
    Map<String, dynamic> params = const {},
    bool allScenes = false,
  ]) {
    _game?.notify(action, params, exclude: this, allScenes: allScenes);
  }

  dynamic login(String email, String password, {bool provideToken = true}) {
    var acc = data.getAccount(email);
    if (acc == null || !acc.encryptedPassword.match(password)) {
      return null;
    }
    return loginAccount(acc, provideToken: provideToken);
  }

  Map<String, dynamic> loginAccount(Account acc, {bool provideToken = false}) {
    // Close the connection to any other user logged into this account
    for (var c in connections) {
      if (c._account == acc) {
        c.ws.sink.close();
        break;
      }
    }

    _account = acc;
    print('Connection logged in with account ' + acc.encryptedEmail.hash);
    var result = acc.toSnippet();

    if (provideToken) {
      for (var entry in tokenAccounts.entries) {
        if (entry.value == acc) {
          tokenAccounts.remove(entry.key);
          break;
        }
      }
      var token = randomAlphaNumeric(16);
      tokenAccounts[token] = acc;
      result.addAll({'token': token});
    }

    return result;
  }

  @override
  void handleBinary(data) {
    if (data is List<int>) {
      if (_game != null) {
        var port = data.first;

        if (port == 80) {
          // Forward measuring event
          _game!.notifyBinary(data, exclude: this);
        } else {
          // Forward map event
          _game!.handleMapEvent(data, this);
        }
      }
    }
  }
}
