import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypt/crypt.dart';
import 'package:dnd_interactive/actions.dart' as a;
import 'package:dnd_interactive/comms.dart';
import 'package:dnd_interactive/point_json.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:pedantic/pedantic.dart';
import 'package:random_string/random_string.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'audio.dart';
import 'data.dart';
import 'mail.dart';
import 'server.dart';

const sendPings = false;

const campaignsPerAccount = 10;
const scenesPerCampaign = 10;
const prefabsPerCampaign = 20;
const mapsPerCampaign = 10;
const movablesPerScene = 50;

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
  Timer _pingTimer;
  Game _game;

  Scene scene;

  Account _account;
  Account get account => _account;

  Connection(this.ws) : broadcastStream = ws.stream.asBroadcastStream() {
    listen(
      onDone: () {
        print('Lost connection (${ws.closeCode})');
        if (ws.closeCode != 1001) {
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

  @override
  Stream get messageStream => broadcastStream;

  @override
  Future<void> send(data) async => ws.sink.add(data);

  @override
  Future handleAction(String action, [Map<String, dynamic> params]) async {
    switch (action) {
      case 'manualSave': // don't know about the safety of this one, chief
        return data.manualSave();

      case a.ACCOUNT_REGISTER:
        var email = params['email'];
        if (data.getAccount(email) != null) {
          return 'Email address already in use!';
        }

        _account = Account(email, params['password']);
        var code = randomAlphaNumeric(5);
        activationCodes[this] = code;
        return await sendVerifyCreationMail(email, code)
            ? true
            : 'Email could not be sent.';

      case a.ACCOUNT_ACTIVATE:
        var actualCode = activationCodes[this];
        String code = params['code'];
        if (actualCode == null || code != actualCode) return null;

        activationCodes.remove(this);
        print('New account activated!');
        data.accounts.add(_account);
        return _account.toSnippet();

      case a.ACCOUNT_LOGIN:
        String email = params['email'];
        String password = params['password'];
        String token = params['token'];
        bool remember = params['remember'] ?? false;
        if (email == null || password == null) {
          if (token == null || tokenAccounts[token] == null) return null;

          return loginAccount(tokenAccounts[token]);
        }

        return login(params['email'], params['password'],
            provideToken: remember);

      case a.ACCOUNT_RESET_PASSWORD:
        var email = params['email'];
        var password = params['password'];
        if (password == null || data.getAccount(email) == null) {
          return 'No account connected to this email address found!';
        }

        var code = randomAlphaNumeric(5);
        resets[this] = PasswordReset(email, password, code);
        return await sendResetPasswordMail(email, code);

      case a.ACCOUNT_RESET_PASSWORD_ACTIVATE:
        var reset = resets[this];
        String code = params['code'];
        if (reset == null || code != reset.code) return null;

        var acc = data.getAccount(reset.email);
        if (acc == null) return null;

        acc.encryptedPassword = Crypt.sha256(reset.password);

        resets.remove(this);
        tokenAccounts.removeWhere((s, a) => a == acc);
        print('Password changed!');
        return loginAccount(acc);

      case a.GAME_CREATE_NEW:
        if (account == null ||
            account.ownedGames.length > campaignsPerAccount) {
          return false;
        }

        var createdMeta = GameMeta.create(account);
        var createdGame = Game(createdMeta);

        if (!createdGame.applyChanges(params['data'])) return false;

        _game = createdGame..connect(this, true);
        scene = _game.playingScene;
        data.gameMeta.add(createdMeta..loadedGame = createdGame);
        account.enteredGames.add(createdMeta);

        // Wait for all images to be uploaded
        var countdown = _game.characters.length;
        for (var i = 0; i < _game.characters.length; i++) {
          unawaited(_uploadGameImage(
            data: params['pics'][i],
            type: a.IMAGE_TYPE_PC,
            id: i,
          ).then((_) => countdown--));
        }

        var sceneDir = Directory('web/images/assets/scene');
        if (await sceneDir.exists()) {
          var count = await sceneDir.list().length;
          var index = Random().nextInt(count);
          var result = await _uploadGameImage(
            data: 'images/$index',
            type: a.IMAGE_TYPE_SCENE,
            id: 0,
          );
          if (result is Map) {
            scene.tiles = result['tiles'];
          }
        }

        return _game.toSessionSnippet(this);

      case a.GAME_EDIT:
        if (account == null) return false;

        var gameId = params['id'];
        var meta = account.ownedGames
            .firstWhere((g) => g.id == gameId, orElse: () => null);
        if (meta == null) return 'Access denied!';

        var game = await meta.open();

        var data = params['data'];
        if (data != null) {
          // User wants to save changes.
          game.notify(
            a.GAME_KICK,
            {
              'reason': '''Your DM updated the campaign settings.
                To correctly reflect all changes, please join again.''',
            },
            allScenes: true,
          );
          var result = game.applyChanges(data);
          await meta.close();
          return result;
        }

        return game.toEditSnippet();

      case a.GAME_DELETE:
        if (account == null) return false;

        var gameId = params['id'];
        var game = account.ownedGames
            .firstWhere((g) => g.id == gameId, orElse: () => null);
        if (game == null) return 'Access denied!';

        await game.delete();

        return true;

      case a.GAME_JOIN:
        var id = params['id'];
        var name = params['name'];
        var meta =
            data.gameMeta.firstWhere((g) => g.id == id, orElse: () => null);

        if (meta != null) {
          var game = meta.loadedGame;

          int id;
          if (meta.owner != account) {
            if (!meta.isLoaded || !game.dmOnline) {
              return 'Your DM is not online!';
            }

            id = await game.dm.request(a.GAME_JOIN_REQUEST, {'name': name});
            if (id == null) return "You're not allowed to enter!";
            game.assignPC(id, this);
          } else {
            game = await meta.open();
          }
          _game = game..connect(this, true);
          scene = game.playingScene;
          return game.toSessionSnippet(this, id);
        }
        return 'Game "$id" not found!';

      case a.GAME_PREFAB_CREATE:
        if (_game != null || _game.prefabCount < prefabsPerCampaign) {
          var p = _game.addPrefab();
          await _uploadGameImageJson(params, id: p.id);
          var json = p.toJson();
          notifyOthers(action, json, true);
          return json;
        }
        return null;

      case a.GAME_PREFAB_UPDATE:
        String pid = params['prefab'];
        var data = params['data'];
        if (_game == null || pid == null) return null;

        var prefab = _game.getPrefab(pid);
        if (prefab == null) return null;

        String src;
        if (data != null) {
          src = await _uploadGameImageJson(params, id: pid);
        } else {
          prefab.fromJson(params);
        }

        notifyOthers(action, params..remove('data'), true);
        return src ?? params;

      case a.GAME_PREFAB_REMOVE:
        if (_game == null) return null;

        _game.removePrefab(params['prefab']);
        return notifyOthers(action, params, true);

      case a.GAME_MOVABLE_CREATE:
        if (scene != null && scene.movables.length < movablesPerScene) {
          var m = scene.addMovable(params);
          if (m == null) return null;
          notifyOthers(action, {
            'id': m.id,
            'x': m.x,
            'y': m.y,
            'prefab': m.prefab,
          });
          return m.id;
        }
        return null;

      case a.GAME_MOVABLE_CREATE_ADVANCED:
        if (scene != null) {
          List source = params['movables'];
          if (scene.movables.length + source.length <= movablesPerScene) {
            var dest = source.map((src) => scene.addMovable(src)).toList();

            notifyOthers(action, {'movables': dest});
            return dest.map((m) => m.id).toList();
          }
        }
        return null;

      case a.GAME_MOVABLE_MOVE:
        List ids = params['movables'];
        var delta = parsePoint(params);
        if (ids == null || delta == null || scene == null) return null;

        for (int movableId in ids) {
          scene.getMovable(movableId)
            ..x += delta.x
            ..y += delta.y;
        }

        return notifyOthers(action, params);

      case a.GAME_MOVABLE_UPDATE:
        var m = scene?.getMovable(params['movable']);
        m?.fromJson(params);
        return notifyOthers(action, params);

      case a.GAME_MOVABLE_REMOVE:
        List ids = params['movables'];

        for (int id in ids) {
          scene?.removeMovable(id);
        }
        return notifyOthers(action, params);

      case a.GAME_CHARACTER_UPLOAD:
        return await _uploadGameImageJson(params);

      case a.GAME_SCENE_UPDATE:
        if (_game?.dm != this || scene == null) return;

        var grid = params['grid'];
        if (grid != null) {
          scene.applyGrid(grid);
          scene.applyMovables(params['movables']);
          return notifyOthers(action, params);
        }

        var img = params['data'];
        if (img != null) {
          var result = await _uploadGameImageJson(params);
          if (result != null) {
            _game.notify(a.GAME_SCENE_UPDATE, {}, exclude: this);
            return result;
          }
        }
        return null;

      case a.GAME_SCENE_GET:
        var sceneId = params['id'];
        var s = _game?.getScene(sceneId);
        if (s == null) return null;

        scene = s;
        return s.toJson();

      case a.GAME_SCENE_PLAY:
        var sceneId = params['id'];
        var scene = _game?.getScene(sceneId);
        if (scene == null) return null;

        _game.playScene(sceneId);
        var result = scene.toJson();
        _game.notify(action, {'id': sceneId, ...result},
            exclude: this, allScenes: true);
        return result;

      case a.GAME_SCENE_ADD:
        var id = _game.sceneCount;
        if (id >= scenesPerCampaign) return null;

        var s = _game?.addScene();
        if (s == null) return null;

        var result = await _uploadGameImageJson(params, id: id);
        if (result is Map) {
          s.tiles = result['tiles'];
        }
        scene = s;
        return s.toJson();

      case a.GAME_SCENE_REMOVE:
        int id = params['id'];
        if (_game == null ||
            _account == null ||
            _game.meta.owner != _account ||
            id == null) return;

        var removed = await _game.removeScene(id);
        if (!removed) return;

        return _game.playingScene.toJson();

      case a.GAME_SCENE_FOG_OF_WAR:
        var data = params['data'];

        if (scene == null || data == null) return false;

        scene.fogOfWar = data;
        _game.notify(action, params, exclude: this);
        return true;

      case a.GAME_ROLL_DICE:
        int charId = params['id'];
        int sides = params['sides'];
        int repeat = params['repeat'];
        bool public = params['public'] ?? true;
        if (sides == null || repeat == null || _game == null) return;

        var results = {
          'sides': sides,
          'results': List.generate(repeat, (_) => data.rng.nextInt(sides) + 1),
          'id': charId,
        };

        if (public) {
          _game.notify(action, results, exclude: this, allScenes: true);
        }
        return results;

      case a.GAME_MAP_CREATE:
        if (_game.mapCount >= mapsPerCampaign) return null;

        var id = _game.addMap();
        await _uploadGameImageJson(params, id: id);
        _game.notify(action, {'map': id}, exclude: this, allScenes: true);
        return id;

      case a.GAME_MAP_UPDATE:
        int id = params['map'];
        String name = params['name'];

        if (name != null) {
          _game.updateMap(id, name);
          _game.notify(action, params, exclude: this, allScenes: true);
          return true;
        }

        await _uploadGameImageJson(params, id: id);
        _game.notify(action, {'map': id}, exclude: this, allScenes: true);
        return true;

      case a.GAME_MAP_REMOVE:
        int id = params['map'];
        if (id == null) return false;

        _game.removeMap(id);
        _game.notify(action, {'map': id}, exclude: this, allScenes: true);
        return true;

      case a.GAME_PING:
        if (_game != null) {
          _game.notify(action, params, exclude: this);
        }
        return true;

      case a.GAME_CHAT:
        if (_game != null) {
          _game.notify(action, params, exclude: this, allScenes: true);
        }
        return true;

      case a.FEEDBACK:
        String type = params['type'];
        String content = params['content'];
        bool acc = params['acc'] ?? false;
        if (content == null ||
            !(type == 'feature' ||
                type == 'bug' ||
                type == 'account' ||
                type == 'other')) return false;

        pendingFeedback.add(Feedback(
          type,
          content,
          acc ? account?.encryptedEmail?.toString() : null,
          _game?.meta?.id,
        ));
        return true;

      case a.GAME_UPDATE_INITIATIVE:
        int pc = params['pc'];
        if (pc != null) {
          _game.characters.elementAt(pc).initiativeMod = params['mod'];
        }
        continue notify;

      notify:
      case a.GAME_ROLL_INITIATIVE:
      case a.GAME_ADD_INITIATIVE:
      case a.GAME_CLEAR_INITIATIVE:
        return _game.notify(action, params, exclude: this, allScenes: true);

      case a.GAME_MUSIC_PLAYLIST:
        var id = params['playlist'];
        if (_game == null) return;

        if (id == null) {
          _game.ambience.playlistName = null;
          _game.ambience.list = null;
          _game.notify(action, null, exclude: this, allScenes: true);
          return null;
        }

        var pl = collection.playlists.firstWhere(
          (pl) => pl.title == id,
          orElse: () => null,
        );

        var tracklist = pl.toTracklist(shuffle: true);
        _game.ambience.playlistName = pl.title;
        _game.ambience.list = tracklist;

        var response = tracklist.toJson();
        _game.notify(action, response, exclude: this, allScenes: true);

        return response;

      case a.GAME_MUSIC_SKIP:
        if (_game == null) return;
        _game.ambience.list.fromSyncJson(params);
        continue notify;

      case a.GAME_MUSIC_AMBIENCE:
        if (_game == null) return;
        _game.ambience.ambienceFromJson(params);
        continue notify;
    }
  }

  Future<dynamic> _uploadGameImage({
    @required String data,
    @required String type,
    @required dynamic id,
    String gameId,
  }) async {
    if (data == null || type == null || id == null) return 'Missing info';

    var meta = gameId != null
        ? account.ownedGames
            .firstWhere((g) => g.id == gameId, orElse: () => null)
        : _game.meta;

    if (meta.isLoaded && meta != null) {
      var file = await meta.loadedGame.getFile('$type$id');
      var result = '$address/${file.path.replaceAll('\\', '/')}';

      if (data.startsWith('images/')) {
        // [base64] is a path to an asset
        var dir = 'web/images/assets/$type/';
        var assetIndex = int.parse(p.basename(data));
        File dataImg = await Directory(dir).list().elementAt(assetIndex);

        await File(dataImg.path).copy(file.path);

        var match = RegExp(r'\d+x\d').firstMatch(dataImg.path);
        if (match != null) {
          var s = match[0];
          return {
            'path': result,
            'tiles': int.parse(s.substring(0, s.indexOf('x'))),
          };
        }
      } else {
        await file.create();
        await file.writeAsBytes(base64Decode(data));
      }

      return result;
    }
    return 'Missing game info';
  }

  Future<dynamic> _uploadGameImageJson(Map<String, dynamic> json,
      {dynamic id}) {
    return _uploadGameImage(
      data: json['data'],
      type: json['type'],
      id: id ?? json['id'],
      gameId: json['gameId'],
    );
  }

  void notifyOthers(
    String action, [
    Map<String, dynamic> params,
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
          _game.notifyBinary(data, exclude: this);
        } else {
          // Forward map event
          _game.handleMapEvent(data, this);
        }
      }
    }
  }
}
