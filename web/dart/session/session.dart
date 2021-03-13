import '../game.dart';
import 'board.dart';
import 'character.dart';

class Session extends Game {
  final bool isGM;
  final characters = <Character>[];
  Board _board;
  Board get board => _board;
  int _charId;
  Character get myCharacter => _charId != null ? characters[_charId] : null;

  Session(String id, String name, this.isGM) : super(id, name, null) {
    _board = Board(this);
  }
  Session.test() : this('what', 'no', null);

  void fromJson(Map<String, dynamic> json) {
    characters.clear();
    characters.addAll(List.from(json['pcs']).map((e) => Character.fromJson(e)));
    _charId = json['mine'];
    print('Hello, ' + (myCharacter?.name ?? 'GM') + '!');
    var scenes = List.from(json['scenes']);
    int current = json['scene'];
    _board.fromJson(current, scenes[current]);
  }
}
