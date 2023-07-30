import 'dart:html';

import 'package:dungeonclub/actions.dart';

import '../html_helpers.dart';
import '../resource.dart';
import 'character.dart';
import 'scene.dart';
import 'session.dart';

class DemoSession extends Session {
  static const demoId = 'sandbox';
  static const demoName = 'Sandbox';

  DemoSession() : super(demoId, demoName, true);

  void initializeDemo() async {
    queryDom('#session').classes.add('demo');

    var demoPlayers = ['Nathaniel', 'Luke', 'Teo'];
    var characters = <Character>[];

    for (var i = 0; i < demoPlayers.length; i++) {
      var color = Session.getUniqueColorForPlayer(i, demoPlayers.length);
      characters.add(Character(i, this,
          color: color, name: demoPlayers[i], avatarUrl: 'asset/pc/$i'));
    }

    scenes.add(Scene(0, Resource('asset/scene/15')));

    await initialize(characters: characters);
  }

  @override
  void initializeBoard(Map sceneJson) {
    board.load(
      sceneID: 0,
      movablesData: [],
      loadGrid: (grid) => grid.configure(
        gridType: GRID_SQUARE,
        tiles: 23,
        tileUnit: 'ft',
        alpha: 0.5,
        color: '#111111',
        position: Point(0, 0),
      ),
    );
  }
}
