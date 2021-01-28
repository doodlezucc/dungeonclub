import 'dart:html';

import 'dart/communication.dart';
import 'dart/user.dart';

final user = User();
final InputElement loginEmail = querySelector('#loginEmail');
final InputElement loginPassword = querySelector('#loginPassword');

void main() {
  wsConnect();

  querySelector('h1').text = 'Eventually... it worked!!!';

  querySelector('button#login').onClick.listen((event) {
    user.login(loginEmail.value, loginPassword.value);
  });

  querySelector('button#create').onClick.listen((event) async {
    var game = await user.account.createNewGame();
    print(game.id);
    print(game.owner);
  });

  querySelector('button#save').onClick.listen((event) async {
    send('{"action":"manualSave"}');
  });
}
