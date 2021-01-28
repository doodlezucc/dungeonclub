import 'account.dart';

class Game {
  String _name;
  String get name => _name;

  final int id;
  final Account owner;

  Game(Map<String, dynamic> json, this.owner) : id = json['id'];
}
