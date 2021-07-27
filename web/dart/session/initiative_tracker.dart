import 'dart:html';
import 'dart:math';

import 'package:dnd_interactive/actions.dart';

import '../../main.dart';
import '../communication.dart';
import '../panels/panel_overlay.dart';
import 'character.dart';
import 'log.dart';
import 'prefab.dart';

void initInitiativeTracker() {
  querySelector('#initiativeTracker')?.onClick?.listen((event) {
    rollForInitiative();
  });
}

void rollForInitiative() {
  for (int i = 0; i < user.session.board.movables.length; i++) {
    Prefab prefab = user.session.board.movables[i].prefab;
    if (prefab is CharacterPrefab) {
      Character character = prefab.character;
      socket.sendAction(GAME_ROLL_INITIATIVE);
    }
  }
}

void ranResInChat() {
  int mod = querySelector('#initiativeMod').nodeValue as int;
  /*var results ={
    'sides': 20,
    'id': user.session.charId,
  };*/
  int initiator = user.session.charId;
  var name = user.session.characters[initiator].name;
  var mine = initiator == null || initiator == user.session.charId;
  int r = Random().nextInt(19) + 1;
  int total = r + mod;
  gameLog('''
    $name rolled $r with an initiative modifier of $mod for a total of $total for initiative''',
      mine: mine);
}

void randomStrudel() {
  while (true) {
    int r = Random().nextInt(19) + 1;
    querySelector('.initiativeRollButton').text = r as String;
  }
}

void showRollerPanel() {
  //querySelector('#initiativeRoll').classes.add('show');
  //overlayVisible = true;
  querySelector('.initiativeRollButton')
    ..onMouseOver.listen((event) {
      randomStrudel();
    })
    ..onClick.listen((event) {
      ranResInChat();
    });
  print('Show Roller Panel');
}
