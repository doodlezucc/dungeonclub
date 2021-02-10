import '../game.dart';
import 'board.dart';

class Session {
  final Game game;
  final Board board;

  Session(this.game) : board = Board();
  Session.test() : this(Game('what', 'no', null));
}
