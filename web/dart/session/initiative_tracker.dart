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
  //print('Roll for Initiative');
  querySelector('.initiativeRollButton').onClick.listen((event) {
    ranResInChat();
  });
}

void rollForInitiative() {
  /*for (int i = 0; i < user.session.board.movables.length; i++) {
    Prefab prefab = user.session.board.movables[i].prefab;
    if (prefab is CharacterPrefab) {
      Character character = prefab.character;
      socket.sendAction(GAME_ROLL_INITIATIVE);
    }
  }*/
  socket.sendAction(GAME_ROLL_INITIATIVE);
}

void ranResInChat() {
  if ((querySelector('#initiativeMod') as InputElement).value == '') return;
  int mod =
      (querySelector('#initiativeMod') as InputElement).valueAsNumber.round();
  /*var results ={
    'sides': 20,
    'id': user.session.charId,
  };*/
  int initiator = user.session.charId;
  var mine = initiator == null || initiator == user.session.charId;
  int r = Random().nextInt(19) + 1;
  int total = r + mod;
  gameLog('''
    You rolled $r with an initiative modifier of $mod for a total of $total for initiative''',
      mine: mine);
  querySelector('#initiativeRoll').classes.remove('show');
  overlayVisible = false;
}

void showRollerPanel() {
  querySelector('#initiativeRoll').classes.add('show');
  (querySelector('#intitativeMod') as InputElement).value = '0';
  overlayVisible = true;
  print('Show Roller Panel');
}
