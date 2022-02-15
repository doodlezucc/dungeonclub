import 'package:dnd_interactive/actions.dart';

import '../communication.dart';
import 'character.dart';
import 'session.dart';

class DemoSession extends Session {
  DemoSession() : super('sandbox', 'Sandbox', true);

  void initializeDemo() {
    var demoPlayers = ['Nathaniel', 'Luke', 'Teo'];
    var characters = <Character>[];

    for (var i = 0; i < demoPlayers.length; i++) {
      var color = getPlayerColor(i, demoPlayers.length);
      registerRedirect('$IMAGE_TYPE_PC$i', 'images/assets/pc/$i');
      characters.add(Character(i, this, color: color, name: demoPlayers[i]));
    }

    registerRedirect(IMAGE_TYPE_SCENE + '0', 'images/assets/scene/0');

    initialize(characters: characters, playingId: 0, sceneCount: 1);
  }
}
