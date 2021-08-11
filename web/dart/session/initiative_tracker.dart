import 'dart:async';
import 'dart:html';
import 'dart:math';

import 'package:dnd_interactive/actions.dart';

import '../../main.dart';
import '../communication.dart';
import '../font_awesome.dart';
import '../panels/panel_overlay.dart';
import 'character.dart';
import 'movable.dart';
import 'prefab.dart';

HtmlElement get initiativeBar => querySelector('#initiativeBar');
HtmlElement get charContainer => initiativeBar.querySelector('.roster');
InitiativeSummary _summary;

class InitiativeTracker {
  final rng = Random();

  bool _trackerActive = false;
  ButtonElement get callRollsButton => querySelector('#initiativeTracker');
  SpanElement get initiativeDice => querySelector('#initiativeDice');
  ButtonElement get userRollButton => querySelector('#initiativeRoll');
  HtmlElement get panel => querySelector('#initiativePanel');

  Timer diceAnim;

  set showBar(bool v) => initiativeBar.classes.toggle('hidden', !v);

  void init() {
    callRollsButton.onClick.listen((event) {
      _trackerActive = callRollsButton.classes.toggle('active');

      if (_trackerActive) {
        rollForInitiative();
      } else {
        outOfCombat();
        socket.sendAction(GAME_CLEAR_INITIATIVE);
      }
    });

    userRollButton.onClick.listen((event) {
      rollDice();
    });
  }

  void rollForInitiative() {
    resetBar();
    socket.sendAction(GAME_ROLL_INITIATIVE);
    // for (var i = 0; i < 15; i++) {
    //   onRollAdd(i % 2, Random().nextInt(20));
    // }
  }

  void rollDice() {
    diceAnim?.cancel();
    var r = Random().nextInt(20) + 1;
    initiativeDice.text = '$r';

    var pc = user.session.charId;
    onRollAdd(pc, r);
    socket.sendAction(GAME_ADD_INITIATIVE, {'id': pc, 'roll': r});

    Future.delayed(Duration(milliseconds: 500), () {
      panel.classes.remove('show');
      overlayVisible = false;
    });
  }

  void onRollAdd(int pc, int total) {
    var movable = user.session.board.movables.firstWhere((m) {
      var pref = m.prefab;
      if (pref is CharacterPrefab) {
        return pref.character.id == pc;
      }
      return false;
    });

    _summary.registerRoll(movable, total);
  }

  void showRollerPanel() {
    resetBar();
    diceAnim?.cancel();

    diceAnim = Timer.periodic(Duration(milliseconds: 50), (_) {
      initiativeDice.text = '${rng.nextInt(20) + 1}';
    });

    panel.classes.add('show');
    overlayVisible = true;
  }

  void resetBar() {
    _summary = InitiativeSummary();
    charContainer.children.clear();
    showBar = true;
  }

  void addToInBar(Map<String, dynamic> json) {
    int id = json['id'];
    int total = json['roll'];
    onRollAdd(id, total);
  }

  void outOfCombat() {
    showBar = false;
    if (panel.classes.remove('show')) overlayVisible = false;
  }

  void onUpdate(Map<String, dynamic> json) {
    int id = json['id'];
    int mod = json['mod'];
    for (var entry in _summary.entries) {
      if (entry.movable.id == id) {
        entry.modifier = mod;
        _summary.sort();
      }
    }
  }
}

class InitiativeSummary {
  List<InitiativeEntry> entries = [];

  void registerRoll(Movable movable, int base) {
    var index = entries.lastIndexWhere((other) => base <= other.total) + 1;

    var entry = InitiativeEntry(movable, base);
    entries.insert(index, entry);

    charContainer.children.insert(index, entry.e);
  }

  void sort() {
    for (var n = entries.length; n > 1; --n) {
      for (var i = 0; i < n - 1; ++i) {
        var a = entries[i];
        var b = entries[i + 1];

        if (a.total < b.total) {
          charContainer.insertBefore(b.e, a.e);

          entries[i] = b;
          entries[i + 1] = a;
        }
      }
    }
  }
}

class InitiativeEntry {
  final e = DivElement();
  final modText = SpanElement();
  final totalText = SpanElement();
  final Movable movable;
  final int base;

  bool get isChar => movable.prefab is CharacterPrefab;
  Character get char =>
      isChar ? (movable.prefab as CharacterPrefab).character : null;
  int get total => base + modifier;

  int _modifier;
  int get modifier => _modifier;
  set modifier(int modifier) {
    _modifier = modifier;
    modText.text = (modifier >= 0 ? '+$modifier' : '$modifier');
    totalText.text = '$total';

    char?.defaultModifier = modifier;
  }

  InitiativeEntry(this.movable, this.base) {
    int _bufferedModifier;

    var img = movable.prefab.img(cacheBreak: false);
    e
      ..className = 'char'
      ..append(SpanElement()
        ..className = 'step-input'
        ..append(icon('minus')..onClick.listen((_) => modifier--))
        ..append(modText)
        ..append(icon('plus')..onClick.listen((_) => modifier++)))
      ..append(DivElement()
        ..style.backgroundImage = 'url($img)'
        ..append(totalText))
      ..append(SpanElement()..text = movable.prefab.name)
      ..onMouseEnter.listen((_) {
        movable.e.classes.add('hovered');
        _bufferedModifier = modifier;
      })
      ..onMouseLeave.listen((_) {
        movable.e.classes.remove('hovered');
        if (modifier != _bufferedModifier) {
          _summary.sort();
          sendUpdate();
        }
      });

    modifier = char?.defaultModifier ?? 0;
  }

  void sendUpdate() {
    socket.sendAction(GAME_UPDATE_INITIATIVE, {
      'id': movable.id,
      'mod': modifier,
      if (isChar) 'pc': char.id,
    });
  }
}
