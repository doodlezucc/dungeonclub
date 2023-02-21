import 'dart:html';

import 'package:dungeonclub/actions.dart';

import 'character.dart';
import 'session.dart';

class DemoSession extends Session {
  static const demoId = 'sandbox';
  static const demoName = 'Sandbox';

  DemoSession() : super(demoId, demoName, true);

  void initializeDemo() async {
    querySelector('#session').classes.add('demo');

    var demoPlayers = ['Nathaniel', 'Luke', 'Teo'];
    var characters = <Character>[];

    for (var i = 0; i < demoPlayers.length; i++) {
      var color = getPlayerColor(i, demoPlayers.length);
      characters.add(Character(i, this,
          color: color, name: demoPlayers[i], avatarUrl: 'assets/pc/$i'));
    }

    await initialize(
      characters: characters,
      overrideSceneBackground: 'assets/scene/15',
    );

    board.grid.configure(
      gridType: GRID_SQUARE,
      tiles: 23,
      tileUnit: 'ft',
      alpha: 0.5,
      color: '#111111',
      position: Point(0, 0),
    );
    board.rescaleMeasurings();
  }
}
