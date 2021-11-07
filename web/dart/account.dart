import 'dart:async';
import 'dart:html';

import '../main.dart';
import 'game.dart';
import 'notif.dart';
import 'panels/edit_game.dart' as edit_game;
import 'panels/panel_overlay.dart';

class Account {
  final List<Game> games;
  final _joinStream = StreamController<bool>.broadcast();
  int _lockJoin = 0;

  Account(Map<String, dynamic> json)
      : games = List.from(json['games'])
            .map((e) => Game(e['id'], e['name'], e['mine']))
            .toList() {
    var token = json['token'];
    if (token != null) {
      window.localStorage['token'] = token;
    }
  }

  Future<Game> createNewGame() async {
    var game = await edit_game.displayPrepare();
    if (game != null) games.add(game);
    return game;
  }

  Future displayPickCharacterDialog(String name) async {
    var notif = HtmlNotification('<b>$name</b> wants to join.');
    document.title = '$name wants to join | $appName';

    var letIn = await notif.prompt();
    document.title = appName;

    if (!letIn) return null;

    _lockJoin++;
    var count = _lockJoin;
    for (var i = 1; i < count; i++) {
      await _joinStream.stream.first;
    }

    var completer = Completer<int>();
    var chars = user.session.characters;

    var available = chars.where((c) => !c.hasJoined);

    if (available.isEmpty) {
      return HtmlNotification('Every available character is already assigned!')
          .display();
    }
    if (available.length == 1) {
      return available.first.id;
    }

    HtmlElement parent = querySelector('#charPick');
    HtmlElement roster = parent.querySelector('.roster');
    List.from(roster.children).forEach((e) => e.remove());

    parent.querySelector('span').innerHtml = "Pick <b>$name</b>'s Character";

    for (var i = 0; i < chars.length; i++) {
      var ch = chars[i];
      roster.append(DivElement()
        ..className = 'char'
        ..classes.toggle('reserved', ch.hasJoined)
        ..append(ImageElement(src: ch.img))
        ..append(SpanElement()..text = ch.name)
        ..onClick.listen((e) {
          ch.hasJoined = true;
          completer.complete(i);
        }));
    }

    overlayVisible = true;
    parent.classes.add('show');
    var result = await completer.future;

    overlayVisible = false;
    parent.classes.remove('show');

    _lockJoin--;
    _joinStream.add(true);
    return result;
  }
}
