import 'dart:convert';
import 'dart:io';

import 'package:dnd_interactive/actions.dart' as a;
import 'package:dnd_interactive/comms.dart';
import 'package:random_string/random_string.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'data.dart';
import 'mail.dart';
import 'server.dart';

final connections = <Connection>[];
final activationCodes = <Connection, String>{};
final tokenAccounts = <String, Account>{};

void onConnect(WebSocketChannel ws) {
  print('New connection!');
  connections.add(Connection(ws));
}

class Connection extends Socket {
  final WebSocketChannel ws;
  final Stream broadcastStream;
  Game _game;

  Scene scene;

  Account _account;
  Account get account => _account;

  Connection(this.ws) : broadcastStream = ws.stream.asBroadcastStream() {
    listen(
      onDone: () {
        print('Lost connection (${ws.closeCode})');
        activationCodes.remove(this);
        _game?.connect(this, false);
        connections.remove(this);
      },
      onError: (err) {
        print('ws error');
        print(err);
        print(ws.closeCode);
        print(ws.closeReason);
      },
    );
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
        if (data.getAccount(email) != null) return false;

        _account = Account(email, params['password']);
        var code = randomAlphaNumeric(5);
        activationCodes[this] = code;
        return await sendVerifyCreationMail(email, code);

      case a.ACCOUNT_ACTIVATE:
        var actualCode = activationCodes[this];
        String code = params['code'];
        if (actualCode == null || code != actualCode) return false;

        activationCodes.remove(this);
        print('New account activated!');
        data.accounts.add(_account);
        return _account.toSnippet();

      case a.ACCOUNT_LOGIN:
        String email = params['email'];
        String password = params['password'];
        String token = params['token'];
        if (email == null || password == null) {
          if (token == null || tokenAccounts[token] == null) return false;

          print('this dude has a token!');
          return loginAccount(tokenAccounts[token]);
        }

        return login(params['email'], params['password']);

      case a.GAME_CREATE_NEW:
        if (account == null) return false;

        _game = Game(account, params['name']);
        scene = _game.playingScene;
        data.games.add(_game);
        account.enteredGames.add(_game);
        return _game.toSessionSnippet(this);

      case a.GAME_EDIT:
        if (account == null) return false;

        var gameId = params['id'];
        var game = account.ownedGames.firstWhere(
            (g) => g.id == gameId && g.online == 0,
            orElse: () => null);
        if (game == null) return 'Access denied!';

        var data = params['data'];
        if (data != null) {
          // User wants to save changes.
          return game.applyChanges(data);
        }

        return game.toSessionSnippet(this);

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
        var game = data.games.firstWhere((g) => g.id == id, orElse: () => null);
        if (game != null) {
          int id;
          if (game.owner != account) {
            if (!game.gmOnline) return 'GM is not online!';

            id = await game.gm.request(a.GAME_JOIN_REQUEST);
            if (id == null) return 'Access denied!';
            game.assignPC(id, this);
          }
          _game = game..connect(this, true);
          scene = game.playingScene;
          return game.toSessionSnippet(this, id);
        }
        return 'Game not found!';

      case a.GAME_PREFAB_CREATE:
        if (_game != null) {
          var p = _game.addPrefab();
          await _uploadGameImageJson(params, id: p.id);
          var json = p.toJson();
          notifyOthers(action, json);
          return json;
        }
        return null;

      case a.GAME_PREFAB_UPDATE:
        String pid = params['prefab'];
        var data = params['data'];
        if (_game == null || pid == null) return null;

        var parsedId = int.parse(pid);

        var prefab = _game.getPrefab(parsedId);
        if (prefab == null) return null;

        String src;
        if (data != null) {
          src = await _uploadGameImageJson(params, id: parsedId);
        }

        notifyOthers(action, params);
        return src ?? json;

      case a.GAME_MOVABLE_CREATE:
        if (scene != null) {
          var m = scene.addMovable(params);
          notifyOthers(action, {
            'id': m.id,
            'x': m.x,
            'y': m.y,
            'prefab': m.prefab,
          });
          return m.id;
        }
        return null;

      case a.GAME_MOVABLE_MOVE:
        var m = scene?.getMovable(params['id']);
        if (m != null) {
          m
            ..x = params['x']
            ..y = params['y'];
        }
        return notifyOthers(action, params);

      case a.GAME_CHARACTER_UPLOAD:
        return await _uploadGameImageJson(params);

      case a.GAME_SCENE_UPDATE:
        if (_game?.gm != this || scene == null) return;

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
        var s = _game?.addScene();
        if (s == null) return null;

        await _uploadGameImageJson(params, id: id);
        scene = s;
        return s.toJson();

      case a.GAME_SCENE_REMOVE:
        int id = params['id'];
        if (_game == null ||
            _account == null ||
            _game.owner != _account ||
            id == null) return;

        var doNotifyOthers = _game.playingSceneId == id;

        var removed = await _game.removeScene(id);
        if (!removed) return;

        var result = _game.playingScene.toJson();
        if (doNotifyOthers) {
          _game.notify(action, {'id': _game.playingSceneId, ...result},
              exclude: this, allScenes: true);
        }
        return result;

      case a.GAME_ROLL_DICE:
        int charId = params['id'];
        int sides = params['sides'];
        int repeat = params['repeat'];
        if (sides == null || repeat == null || _game == null) return;

        var results = {
          'sides': sides,
          'results': List.generate(repeat, (_) => data.rng.nextInt(sides) + 1),
          'id': charId,
        };

        if (charId != null) {
          _game.notify(action, results, exclude: this, allScenes: true);
        }
        return results;
    }
  }

  Future<String> _uploadGameImage({
    String base64,
    String type,
    int id,
    String gameId,
  }) async {
    if (base64 == null || type == null || id == null) return 'Missing info';

    var game = gameId != null
        ? account.ownedGames
            .firstWhere((g) => g.id == gameId, orElse: () => null)
        : _game;

    if (game != null) {
      var file = await (await game.getFile('$type$id.png')).create();

      await file.writeAsBytes(base64Decode(base64));
      return '$address/${file.path.replaceAll('\\', '/')}';
    }
    return 'Missing game info';
  }

  Future<String> _uploadGameImageJson(Map<String, dynamic> json, {int id}) {
    return _uploadGameImage(
      base64: json['data'],
      type: json['type'],
      id: id ?? json['id'],
      gameId: json['gameId'],
    );
  }

  void notifyOthers(String action, [Map<String, dynamic> params]) {
    _game?.notify(action, params, exclude: this);
  }

  dynamic login(String email, String password, {bool provideToken = true}) {
    var acc = data.getAccount(email);
    if (acc == null || !acc.encryptedPassword.match(password)) {
      return false;
    }

    var result = loginAccount(acc);
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

  Map<String, dynamic> loginAccount(Account acc) {
    _account = acc;
    print('Connection logged in with account ' + acc.encryptedEmail.hash);
    return acc.toSnippet();
  }
}
