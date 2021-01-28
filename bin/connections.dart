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

        var game = Game(account, params['name']);
        data.games.add(game);
        account.enteredGames.add(game);
        return game.id;
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
