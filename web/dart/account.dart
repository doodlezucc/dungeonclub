import 'dart:html';

import 'communication.dart';
import 'game.dart';
import 'server_actions.dart';
import 'session/session.dart';

class Account {
  //final String name = 'noname';
}

class MyAccount extends Account {
  final String email;
  final games = <Game>[];

  MyAccount(Map<String, dynamic> json) : email = json['email'];

  Future<Session> createNewGame(String name) async {
    var id = await socket.request(GAME_CREATE_NEW, {'name': name});
    if (id == false) return null;

    return Session(id, name, true);
  }

  Future displayJoinRequestDialog(String name) async {
    var v = window.confirm('$name wants to join');
    if (!v) return null;

    return 1; // in-game character id
  }
}
