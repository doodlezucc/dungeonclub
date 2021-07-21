import 'dart:async';
import 'dart:html';

import '../main.dart';
import 'game.dart';
import 'notif.dart';
import 'panels/edit_game.dart' as edit_game;
import 'panels/panel_overlay.dart';

class Account {
  final String email;
  final List<Game> games;

  Account(Map<String, dynamic> json)
      : email = json['email'],
        games = List.from(json['games'])
            .map((e) => Game(e['id'], e['name'], e['mine']))
            .toList() {
    var token = json['token'];
    if (token != null) {
      print('Saving token $token');
      window.localStorage['token'] = token;
    }
  }

  Future<Game> createNewGame() async {
    var game = await edit_game.displayPrepare();
    if (game != null) games.add(game);
    return game;
  }

  Future displayPickCharacterDialog(String name) async {
    var notif = HtmlNotification('<b>$name</b> wants to join');
    document.title = '$name wants to join | $appName';

    var letIn = await notif.prompt();
    document.title = appName;

    if (!letIn) return null;

    var completer = Completer<int>();
    var chars = user.session.characters;

    var available = chars.where((c) => !c.hasJoined);

    if (available.isEmpty) {
      print('Every available character is already assigned!');
      return null;
    }
    if (available.length == 1) {
      return available.first.id;
    }

    HtmlElement parent = querySelector('#charPick');
    HtmlElement roster = parent.querySelector('.roster');
    List.from(roster.children).forEach((e) => e.remove());

    parent.querySelector('span').innerHtml = "Pick <b>$name</b>'s character";

    for (var i = 0; i < chars.length; i++) {
      var ch = chars[i];
      roster.append(DivElement()
        ..className = 'char'
        ..classes.toggle('reserved', ch.hasJoined)
        ..append(ImageElement(src: ch.img))
        ..append(SpanElement()..text = ch.name)
        ..onClick.listen((e) => completer.complete(i)));
    }

    overlayVisible = true;
    parent.classes.add('show');
    var result = await completer.future;

    overlayVisible = false;
    parent.classes.remove('show');
    return result;
  }
}
