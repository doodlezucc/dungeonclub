import 'package:web_socket_channel/web_socket_channel.dart';

import '../web/dart/server_actions.dart' as a;
import '../web/comms.dart';
import 'data.dart';
import 'server.dart';

final connections = <Connection>[];

void onConnect(WebSocketChannel ws) {
  print('New connection!');
  connections.add(Connection(ws));
}

class Connection extends Socket {
  final WebSocketChannel ws;
  final Stream broadcastStream;
  Game _game;
  Account _account;
  Account get account => _account;

  Connection(this.ws) : broadcastStream = ws.stream.asBroadcastStream() {
    listen(
      onDone: () {
        print('Lost connection (${ws.closeCode})');
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

        _game = Game(account, params['name'])..connect(this, true);
        data.games.add(_game);
        account.enteredGames.add(_game);
        return _game.id;

      case a.GAME_JOIN:
        var id = params['id'];
        var game = data.games.firstWhere((g) => g.id == id, orElse: () => null);
        if (game != null) {
          PlayerCharacter pc;
          if (game.owner != account) {
            if (!game.gmOnline) return 'GM is not online!';

            var charId = await game.gm.request(a.GAME_JOIN_REQUEST);
            if (charId == null) return 'Access denied!';
            pc = game.assignPC(charId, this);
          }
          _game = game..connect(this, true);
          return game.toSessionSnippet(this, pc);
        }
        return 'Game not found!';

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
        return false;

      case a.GAME_MOVABLE_MOVE:
        var m = _game?.board?.getMovable(params['id']);
        if (m != null) {
          m
            ..x = params['x']
            ..y = params['y'];
        }
        return notifyOthers(action, params);
    }
  }

  void notifyOthers(String action, [Map<String, dynamic> params]) {
    _game?.notify(action, params, exclude: this);
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
