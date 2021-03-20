import 'dart:html';

import 'dart/communication.dart';
import 'dart/panels/edit_game.dart' as edit_game;
import 'dart/panels/register.dart' as register;
import 'dart/user.dart';

final user = User();
final InputElement loginEmail = querySelector('#loginEmail');
final InputElement loginPassword = querySelector('#loginPassword');
const appName = 'D&D Interactive';

void main() {
  _listenToCssReload();
  socket.connect();

  print('Ready!');

  querySelector('button#login').onClick.listen((_) async {
    await user.login(loginEmail.value, loginPassword.value);
  });
  querySelector('button#signup').onClick.listen((_) {
    register.display();
  });

  querySelector('button#save').onClick.listen((_) {
    socket.send('{"action":"manualSave"}');
  });

  querySelector('button#joinDemo').onClick.listen((_) {
    user.joinSession('pog');
  });

  _initBrightnessSwitch();

  document.onDrop.listen((e) => e.preventDefault());
  document.onDragOver.listen((e) => e.preventDefault());

  //testFlow();
}

Future<void> testFlow() async {
  var edit = true;

  await user.login(loginEmail.value, loginPassword.value);
  if (edit) {
    await edit_game.display(user.account.games.first);
  } else {
    await user.joinSession(user.account.games.first.id);
  }
}

void _initBrightnessSwitch() {
  var key = 'darkMode';
  var cl = 'dark-mode';

  document.body.classes.toggle(cl, window.localStorage[key] != 'false');

  querySelector('button#brightness').onClick.listen((_) {
    var dark = document.body.classes.toggle(cl);
    window.localStorage[key] = '$dark';
  });
}

void _listenToCssReload() {
  document.onKeyPress.listen((event) {
    if (event.target is InputElement) return;
    if (event.key == 'R') {
      querySelectorAll<LinkElement>('link').forEach((link) => link.href += '');
    }
  });
}
