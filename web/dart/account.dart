import 'dart:async';
import 'dart:html';

import 'package:dnd_interactive/actions.dart';

import '../main.dart';
import 'communication.dart';
import 'game.dart';
import 'notif.dart';
import 'session/session.dart';

class Account {
  //final String name = 'noname';
}

class MyAccount extends Account {
  final String email;
  final List<Game> games;

  MyAccount(Map<String, dynamic> json)
      : email = json['email'],
        games = List.from(json['games'])
            .map((e) => Game(e['id'], e['name'], null))
            .toList();

  Future<Session> createNewGame(String name) async {
    var id = await socket.request(GAME_CREATE_NEW, {'name': name});
    if (id == false) return null;

    return Session(id, name, true);
  }

  Future displayPickCharacterDialog(String name) async {
    var notif = HtmlNotification('<b>$name</b> wants to join');
    document.title = '$name wants to join | $appName';

    var letIn = await notif.prompt();
    document.title = appName;

    if (!letIn) return null;

    var completer = Completer<int>();
    var chars = user.session.characters;

    HtmlElement parent = querySelector('#charPick');
    HtmlElement roster = parent.querySelector('.roster');
    List.from(roster.children).forEach((e) => e.remove());

    parent.querySelector('span').innerHtml = "Pick <b>$name</b>'s character";

    for (var i = 0; i < chars.length; i++) {
      var ch = chars[i];
      roster.append(DivElement()
        ..className = 'char'
        ..append(ImageElement())
        ..append(SpanElement()..text = ch.name)
        ..onClick.listen((e) => completer.complete(i)));
    }

    parent.classes.add('show');

    var result = await completer.future;
    parent.classes.remove('show');
    return result;
  }
}
