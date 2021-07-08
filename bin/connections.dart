import 'dart:convert';

import 'package:crypt/crypt.dart';
import 'package:dnd_interactive/actions.dart' as a;
import 'package:dnd_interactive/comms.dart';
import 'package:meta/meta.dart';
import 'package:pedantic/pedantic.dart';
import 'package:random_string/random_string.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'data.dart';
import 'mail.dart';
import 'server.dart';

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
  Game _game;

  Scene scene;

  Account _account;
  Account get account => _account;

  Connection(this.ws) : broadcastStream = ws.stream.asBroadcastStream() {
    listen(
      onDone: () {
        print('Lost connection (${ws.closeCode})');
        activationCodes.remove(this);
        resets.remove(this);
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
        if (reset == null || code != reset.code) return false;

        var acc = data.getAccount(reset.email);
        if (acc == null) return false;

        acc.encryptedPassword = Crypt.sha256(reset.password);

        resets.remove(this);
        print('Password changed!');
        return loginAccount(acc);

      case a.GAME_CREATE_NEW:
        if (account == null) return false;

        var createdGame = Game(account, '');
        if (!createdGame.applyChanges(params['data'])) return false;

        _game = createdGame..connect(this, true);
        scene = _game.playingScene;
        data.games.add(_game);
        account.enteredGames.add(_game);

        // Wait for all images to be uploaded
        var countdown = _game.characters.length;
        for (var i = 0; i < _game.characters.length; i++) {
          unawaited(_uploadGameImage(
            base64: params['pics'][i],
            type: a.IMAGE_TYPE_PC,
            id: i,
          ).then((_) => countdown--));
        }

        await _uploadGameImage(
          base64: params['scene'],
          type: a.IMAGE_TYPE_SCENE,
          id: 0,
        );

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
        var name = params['name'];
        var game = data.games.firstWhere((g) => g.id == id, orElse: () => null);
        if (game != null) {
          int id;
          if (game.owner != account) {
            if (!game.dmOnline) return 'Your DM is not online!';

            id = await game.dm.request(a.GAME_JOIN_REQUEST, {'name': name});
            if (id == null) return "You're not allowed to enter!";
            game.assignPC(id, this);
          }
          _game = game..connect(this, true);
          scene = game.playingScene;
          return game.toSessionSnippet(this, id);
        }
        return 'Game "$id" not found!';

      case a.GAME_PREFAB_CREATE:
        if (_game != null) {
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
        var m = scene?.getMovable(params['movable']);
        if (m != null) {
          m
            ..x = params['x']
            ..y = params['y'];
        }
        return notifyOthers(action, params);

      case a.GAME_MOVABLE_UPDATE:
        var m = scene?.getMovable(params['movable']);
        m?.fromJson(params);
        return notifyOthers(action, params);

      case a.GAME_MOVABLE_REMOVE:
        scene?.removeMovable(params['movable']);
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

      case a.GAME_MAP_CREATE:
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
    }
  }

  Future<String> _uploadGameImage({
    @required String base64,
    @required String type,
    @required dynamic id,
    String gameId,
  }) async {
    if (base64 == null || type == null || id == null) return 'Missing info';

    var game = gameId != null
        ? account.ownedGames
            .firstWhere((g) => g.id == gameId, orElse: () => null)
        : _game;

    if (game != null) {
      var file = await (await game.getFile('$type$id')).create();

      await file.writeAsBytes(base64Decode(base64));
      return '$address/${file.path.replaceAll('\\', '/')}';
    }
    return 'Missing game info';
  }

  Future<String> _uploadGameImageJson(Map<String, dynamic> json, {dynamic id}) {
    return _uploadGameImage(
      base64: json['data'],
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
      return false;
    }
    return loginAccount(acc, provideToken: provideToken);
  }

  Map<String, dynamic> loginAccount(Account acc, {bool provideToken = false}) {
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
    if (_game != null) {
      _game.handleMapEvent(data, this);
    }
  }
}
