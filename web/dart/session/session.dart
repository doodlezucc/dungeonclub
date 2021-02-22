import '../game.dart';
import 'board.dart';
import 'character.dart';

class Session extends Game {
  final bool isGM;
  final characters = <Character>[];
  Board _board;
  Board get board => _board;
  MyCharacter _myCharacter;
  MyCharacter get myCharacter => _myCharacter;

  Session(String id, String name, this.isGM) : super(id, name, null) {
    _board = Board(this);
  }
  Session.test() : this('what', 'no', null);

  void fromJson(Map<String, dynamic> json) {
    characters.clear();
    characters.addAll(List.from(json['pcs']).map((e) => Character.fromJson(e)));
    if (json['mine'] != null) {
      _myCharacter = MyCharacter.fromJson(json['mine']);
    }
    print('Hello, ' + (_myCharacter?.name ?? 'DM') + '!');
    _board.fromJson(json['board']);
  }
}
