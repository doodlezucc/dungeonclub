import 'communication.dart';
import 'game.dart';
import 'server_actions.dart';

class Account {
  final String email;
  final games = <Game>[];

  Account(Map<String, dynamic> json) : email = json['email'];

  Future<Game> createNewGame() async {
    var json = await request(GAME_CREATE_NEW);
    return Game(json, this);
  }
}
