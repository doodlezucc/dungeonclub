import 'communication.dart';
import 'game.dart';
import 'server_actions.dart';

class Account {
  //final String name = 'noname';
}

class MyAccount extends Account {
  final String email;
  final games = <Game>[];

  MyAccount(Map<String, dynamic> json) : email = json['email'];

  Future<Game> createNewGame(String name) async {
    var id = await request(GAME_CREATE_NEW, {'name': name});
    if (id == false) return null;

    return Game(id, name, this);
  }
}
