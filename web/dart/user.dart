import 'package:dnd_interactive/actions.dart';

import 'account.dart';
import 'communication.dart';
import 'section_page.dart';
import 'session/session.dart';

class User {
  MyAccount _account;
  MyAccount get account => _account;

  bool get registered => account != null;

  Session _session;
  Session get session => _session;

  Future<bool> joinSession(String id) async {
    var s = await socket.request(GAME_JOIN, {'id': id});
    if (s is String) return false;

    _session = Session(id, s['name'], s['gm'] != null)..fromJson(s);
    showPage('session');
    return true;
  }

  Future<void> login(String email, String password,
      {bool signUp = false}) async {
    var response = await socket.request(
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
