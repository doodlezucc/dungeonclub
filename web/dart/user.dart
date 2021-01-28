import 'account.dart';
import 'communication.dart';
import 'server_actions.dart';
import 'session/session.dart';

class User {
  Account _account;
  Account get account => _account;

  bool get registered => account != null;

  Session _session;
  Session get session => _session;

  Future<void> login(String email, String password) async {
    var response = await request(ACCOUNT_LOGIN, params: {
      'email': email,
      'password': password,
    });
    if (response != false) {
      _account = Account(response);
    } else {
      print('Login failed!');
    }
  }
}
