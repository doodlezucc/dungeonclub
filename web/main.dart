import 'dart:html';

import 'package:path/path.dart';

import 'dart/communication.dart';
import 'dart/home.dart' as home;
import 'dart/panels/code_panel.dart';
import 'dart/panels/edit_game.dart' as edit_game;
import 'dart/panels/join_session.dart' as join_session;
import 'dart/user.dart';

final user = User();
const appName = 'D&D Interactive';

void main() async {
  _listenToCssReload();
  socket.connect();

  print('Ready!');

  querySelector('#signup').onClick.listen((_) {
    registerPanel.display();
  });

  querySelector('button#save').onClick.listen((_) {
    socket.send('{"action":"manualSave"}');
  });

  _initBrightnessSwitch();

  document.onDrop.listen((e) => e.preventDefault());
  document.onDragOver.listen((e) => e.preventDefault());
  window.onPopState.listen((_) => window.location.reload());

  await home.init();
  processUrlPath();

  //testFlow();
}

Future<void> testFlow() async {
  var edit = false;

  await Future.delayed(Duration(milliseconds: 200));
  if (!user.registered) return print('No login token provided');

  if (edit) {
    await edit_game.display(user.account.games.first);
  } else {
    await user.joinSession(user.account.games.first.id);
  }
}

void processUrlPath() {
  var homeUrl = dirname(window.location.href);
  if (window.location.href.contains('game')) {
    var gameId = window.location.pathname;

    if (gameId.contains('game/')) {
      gameId = gameId.substring(gameId.indexOf('game/') + 5);
      homeUrl = dirname(homeUrl);
    } else {
      gameId = window.location.search;
      gameId = gameId.substring(gameId.indexOf('?game=') + 6);

      if (gameId.contains('&')) {
        gameId = gameId.substring(0, gameId.indexOf('&'));
      }
    }

    if (gameId.length >= 3) {
      if (user.registered && user.account.games.any((g) => g.id == gameId)) {
        user.joinSession(gameId);
      } else {
        join_session.display(gameId);
      }
    }
  }

  (querySelector('a.title') as AnchorElement).href = homeUrl;
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
