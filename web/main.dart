import 'dart:async';
import 'dart:html';

import 'package:dnd_interactive/environment.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';

import 'dart/communication.dart';
import 'dart/home.dart' as home;
import 'dart/panels/code_panel.dart';
import 'dart/panels/join_session.dart' as join_session;
import 'dart/panels/feedback.dart' as feedback;
import 'dart/session/demo.dart';
import 'dart/user.dart';

final _interaction = Completer();
Future get requireFirstInteraction => _interaction.future;

final user = User();
const appName = 'Dungeon Club';
String _homeUrl;
String get homeUrl => _homeUrl;

void main() async {
  _listenToCssReload();
  applyEnvironmentStyling();

  print('Ready!');

  querySelector('#signup').onClick.listen((_) {
    registerPanel.display();
  });
  querySelector('#feedback').onClick.listen((_) {
    feedback.display();
  });

  querySelector('button#save').onClick.listen((_) {
    socket.send('{"action":"manualSave"}');
  });

  document.onDrop.listen((e) => e.preventDefault());
  document.onDragOver.listen((e) => e.preventDefault());
  window.onPopState.listen((_) => window.location.reload());
  unawaited(document.onMouseDown.first.then((_) => _interaction.complete()));

  _homeUrl = dirname(window.location.href);
  await home.init();
  processUrlPath();
}

void applyEnvironmentStyling() {
  document.body.classes.toggle('no-music', !Environment.enableMusic);
  if (Environment.isCompiled) {
    querySelector('#privacy').remove();
    var time = DateTime.fromMillisecondsSinceEpoch(Environment.buildTimestamp);
    var buildTime = DateFormat('y-MM-dd').format(time);
    querySelector('#hostInfo').innerHtml = 'Self-Hosted (Build $buildTime)';
  }
}

void processUrlPath() {
  if (window.location.href.contains('game')) {
    var gameId = window.location.pathname;

    if (gameId.contains('game/')) {
      gameId = gameId.substring(gameId.indexOf('game/') + 5);
      _homeUrl = dirname(_homeUrl);
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
      } else if (gameId == DemoSession.demoId) {
        user.joinDemo();
      } else {
        join_session.display(gameId);
      }
    }
  }

  (querySelector('a.title') as AnchorElement).href = _homeUrl;
}

void _listenToCssReload() {
  document.onKeyPress.listen((event) {
    if (event.target is InputElement) return;
    if (event.key == 'R') {
      querySelectorAll<LinkElement>('link').forEach((link) => link.href += '');
    }
  });
}
