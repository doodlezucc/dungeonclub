import 'dart:html';

import 'dart/communication.dart';
import 'dart/session/session.dart';
import 'dart/user.dart';

final user = User();
final InputElement loginEmail = querySelector('#loginEmail');
final InputElement loginPassword = querySelector('#loginPassword');

void main() {
  wsConnect();

  querySelector('h1').text = 'Eventually... it worked!!!';

  querySelector('button#login').onClick.listen((_) {
    user.login(loginEmail.value, loginPassword.value);
  });
  querySelector('button#signup').onClick.listen((_) {
    user.login(loginEmail.value, loginPassword.value, signUp: true);
  });

  querySelector('button#create').onClick.listen((_) async {
    var game = await user.account.createNewGame('Cool Campaign');
    print(game.id);
    print(game.name);
  });

  querySelector('button#save').onClick.listen((_) async {
    send('{"action":"manualSave"}');
  });

  Session.test();
}
