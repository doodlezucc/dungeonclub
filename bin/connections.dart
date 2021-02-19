import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../web/dart/server_actions.dart' as a;
import 'data.dart';
import 'server.dart';

final connections = <Connection>[];

void onConnect(WebSocketChannel ws) {
  print('New connection!');
  connections.add(Connection(ws));
}

class Connection {
  final WebSocketChannel ws;
  Game _game;
  Account _account;
  Account get account => _account;

  Connection(this.ws) {
    ws.stream.listen((data) async {
      print(data);
      if (data is String && data[0] == '{') {
        var json = jsonDecode(data);

        var result = await handleAction(json['action'], json['params']);

        var id = json['id'];
        if (id != null) {
          print('Processed a job called $id or summin idk');
          ws.sink.add(jsonEncode({'id': id, 'result': result}));
        }
      }
    }, onDone: () {
      print('Lost connection (${ws.closeCode})');
      connections.remove(this);
    }, onError: (err) {
      print('ws error');
      print(err);
      print(ws.closeCode);
      print(ws.closeReason);
    });
  }

  void sendAction(String action, [Map<String, dynamic> params]) {
    ws.sink.add(jsonEncode({
      'action': action,
      if (params != null) 'params': params,
    }));
  }

  void notifyOthers(String action, [Map<String, dynamic> params]) {
    if (_game != null) {
      for (var c in _game.connections) {
        if (c != this) {
          c.sendAction(action, params);
        }
      }
    }
  }

  Future<dynamic> handleAction(
      String action, Map<String, dynamic> params) async {
    switch (action) {
      case 'manualSave': // don't know about the safety of this one, chief
        return data.manualSave();

      case a.ACCOUNT_CREATE:
        var email = params['email'];
        if (data.getAccount(email) != null) {
          return false;
        }
        _account = Account(email, params['password']);
        data.accounts.add(_account);
        return _account.toSnippet();

      case a.ACCOUNT_LOGIN:
        return login(params['email'], params['password']);

      case a.GAME_CREATE_NEW:
        if (account == null) return false;

        _game = Game(account, params['name'])..connections.add(this);
        data.games.add(_game);
        account.enteredGames.add(_game);
        return _game.id;

      case a.GAME_MOVABLE_CREATE:
        if (_game != null) {
          var m = _game.board.addMovable(params);
          notifyOthers(action, {
            'id': m.id,
            'x': m.x,
            'y': m.y,
            'img': m.img,
          });
          return m.id;
        }
        return;

      case a.GAME_MOVABLE_MOVE:
        var m = _game?.board?.getMovable(params['id']);
        if (m != null) {
          m
            ..x = params['x']
            ..y = params['y'];
        }
        return notifyOthers(action);
    }
  }

  dynamic login(String email, String password) {
    var acc = data.getAccount(email);
    if (acc == null) {
      return false;
    }
    _account = acc;
    print('Connection logged in with account ' + acc.encryptedEmail.hash);
    return acc.toSnippet();
  }
}
