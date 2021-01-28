import 'account.dart';

class Game {
  String _name;
  String get name => _name;

  final String id;
  final Account owner;

  Game(this.id, String name, this.owner) : _name = name;
}
