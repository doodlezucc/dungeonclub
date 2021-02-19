import 'dart:html';

import 'dart/communication.dart';
import 'dart/session/session.dart';
import 'dart/user.dart';

final user = User();
final InputElement loginEmail = querySelector('#loginEmail');
final InputElement loginPassword = querySelector('#loginPassword');
Session session;

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
    if (!user.registered) return print('No permissions to create a new game!');
    var game = await user.account.createNewGame('Cool Campaign');
    print(game.id);
    print(game.name);
    session = Session(game, true);
    return session.board.addMovable(
        'https://i.kym-cdn.com/photos/images/newsfeed/000/096/044/trollface.jpg?1296494117');
  });

  querySelector('button#save').onClick.listen((_) {
    send('{"action":"manualSave"}');
  });

  //session = Session.test()
}
