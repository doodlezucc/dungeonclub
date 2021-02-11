import '../game.dart';
import 'board.dart';

class Session {
  final Game game;
  final bool isGM;
  Board _board;
  Board get board => _board;

  Session(this.game, this.isGM) {
    _board = Board(this);
  }
  Session.test() : this(Game('what', 'no', null), true);
}
