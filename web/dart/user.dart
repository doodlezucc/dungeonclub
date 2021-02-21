import 'account.dart';
import 'communication.dart';
import 'game.dart';
import 'server_actions.dart';
import 'session/session.dart';

class User {
  MyAccount _account;
  MyAccount get account => _account;

  bool get registered => account != null;

  Session _session;
  Session get session => _session;
  set session(Session session) {
    _session = session;
  }

  Future<bool> joinSession(String id) async {
    var s = await request(GAME_JOIN, {'id': id});
    if (s is String) return false;

    session = Session(Game(id, s['name'], Account()), s['isGM'])
      ..board.fromJson(s['board']);
    return true;
  }

  Future<void> login(String email, String password,
      {bool signUp = false}) async {
    var response = await request(
      signUp ? ACCOUNT_CREATE : ACCOUNT_LOGIN,
      {
        'email': email,
        'password': password,
      },
    );
    if (response != false) {
      _account = MyAccount(response);
    } else {
      print('Login failed!');
    }
  }
}
