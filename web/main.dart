import 'dart:html';

import 'dart/communication.dart';
import 'dart/panels/edit_game.dart' as edit_game;
import 'dart/user.dart';

final user = User();
final InputElement loginEmail = querySelector('#loginEmail');
final InputElement loginPassword = querySelector('#loginPassword');
const appName = 'D&D Interactive';

void main() {
  _listenToCssReload();
  socket.connect();

  print('Ready!');

  querySelector('button#login').onClick.listen((_) {
    user.login(loginEmail.value, loginPassword.value);
  });
  querySelector('button#signup').onClick.listen((_) {
    user.login(loginEmail.value, loginPassword.value, signUp: true);
  });

  querySelector('button#join').onClick.listen((_) {
    return user.joinSession('pog');
  });

  querySelector('button#create').onClick.listen((_) async {
    if (!user.registered) return print('No permissions to create a new game!');
    user.session = await user.account.createNewGame('Cool Campaign');
    return user.session.board.addMovable(
        'https://i.kym-cdn.com/photos/images/newsfeed/000/096/044/trollface.jpg?1296494117');
  });

  querySelector('button#save').onClick.listen((_) {
    socket.send('{"action":"manualSave"}');
  });

  querySelector('button#editGame').onClick.listen((_) {
    if (user.registered) {
      edit_game.display(user.account.games.first);
    }
  });

  //testFlow();
}

void testFlow() {
  user.login(loginEmail.value, loginPassword.value);
}

void _listenToCssReload() {
  document.onKeyPress.listen((event) {
    if (event.target is InputElement) return;
    if (event.key == 'R') {
      querySelectorAll<LinkElement>('link').forEach((link) => link.href += '');
    }
  });
}
