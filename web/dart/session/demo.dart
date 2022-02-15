import 'character.dart';
import 'session.dart';

class DemoSession extends Session {
  DemoSession() : super('sandbox', 'Sandbox', true);

  void initializeDemo() {
    var demoPlayers = ['Nathaniel', 'Luke', 'Teo'];
    var characters = <Character>[];

    for (var i = 0; i < demoPlayers.length; i++) {
      var color = getPlayerColor(i, demoPlayers.length);
      characters.add(Character(i, this, color: color, name: demoPlayers[i]));
    }

    initialize(characters: characters, playingId: 0, sceneCount: 1);
  }
}
