import 'dart:html';
import 'dart:math';

import 'package:dnd_interactive/actions.dart';

import '../../main.dart';
import '../communication.dart';
import '../panels/panel_overlay.dart';
import 'log.dart';

Map<int, HtmlElement> inBar = {};

void initInitiativeTracker() {
  querySelector('#initiativeTracker').onClick.listen((event) {
    rollForInitiative();
  });
  querySelector('.initiativeRollButton').onClick.listen((event) {
    ranResInChat();
  });
}

void rollForInitiative() {
  clearInBar();
  socket.sendAction(GAME_ROLL_INITIATIVE);
}

void ranResInChat() {
  if ((querySelector('#initiativeMod') as InputElement).value == '') return;
  var mod =
      (querySelector('#initiativeMod') as InputElement).valueAsNumber.round();
  var initiator = user.session.charId;
  var mine = initiator == null || initiator == user.session.charId;
  var r = Random().nextInt(19) + 1;
  var total = r + mod;
  gameLog('''
    You rolled $r with an initiative modifier of $mod for a total of $total for initiative''',
      mine: mine);
  querySelector('#initiativeRoll').classes.remove('show');
  overlayVisible = false;
  addToInBar({'id': user.session.charId, 'total': total});
  socket.sendAction(
      GAME_ADD_INITIATIVE, {'id': user.session.charId, 'total': total});
}

void showRollerPanel() {
  clearInBar();
  querySelector('#initiativeRoll').classes.add('show');
  //(querySelector('#intitativeMod') as InputElement).value = '0';
  overlayVisible = true;
  //print('Show Roller Panel');
}

void clearInBar() {
  inBar.clear();
  querySelector('#initiativeBar')
    ..classes.remove('panel')
    ..children.clear();
}

int bag(int a, b) {
  if (a > b) {
    return a;
  }
  return b;
}

Map<int, HtmlElement> sort(Map<int, HtmlElement> m) {
  var r = <int, HtmlElement>{};
  List sortedKeys = m.keys.toList()..sort((a, b) => bag(a, b));
  for (var i = 0; i < sortedKeys.length; i++) {
    r[sortedKeys[i]] = m[sortedKeys[i]];
  }
  return r;
}

void printInBar() {
  var keep = sort(inBar);
  clearInBar();
  inBar = {...keep};
  keep.clear();
  querySelector('#initiativeBar').classes.add('panel');
  inBar.forEach((key, value) {
    querySelector('#initiativeBar').append(value);
  });
}

void addToInBar(Map<String, dynamic> p) {
  HtmlElement elem = ImageElement(
      src: user.session.characters[p['id']].prefab.img(cacheBreak: false),
      height: 50,
      width: 50);
  elem.style.borderRadius = '50%';
  int initiative = p['total'];
  inBar[initiative] = elem;
  printInBar();
}
