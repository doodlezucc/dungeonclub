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
  Timer diceAnim;

  ButtonElement get callRollsButton => querySelector('#initiativeTracker');
  SpanElement get initiativeDice => querySelector('#initiativeDice');
  SpanElement get targetText => querySelector('#initiativeTarget');
  ButtonElement get userRollButton => querySelector('#initiativeRoll');
  HtmlElement get panel => querySelector('#initiativePanel');

  set showBar(bool v) => initiativeBar.classes.toggle('hidden', !v);
  set disabled(bool disabled) => callRollsButton.disabled = disabled;

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
    var r = rng.nextInt(20) + 1;
    initiativeDice.text = '$r';

    var movable = _summary.mine.removeAt(0);

    _summary.registerRoll(movable, r);
    socket.sendAction(GAME_ADD_INITIATIVE, {'id': movable.id, 'roll': r});

    Future.delayed(Duration(milliseconds: 500), () {
      panel.classes.remove('show');
      overlayVisible = false;
      nextRoll();
    });
  }

  void addToInBar(Map<String, dynamic> json) {
    int id = json['id'];
    int total = json['roll'];
    for (var movable in user.session.board.movables) {
      if (id == movable.id) {
        return _summary.registerRoll(movable, total);
      }
    }
  }

  void showRollerPanel() {
    resetBar();
    nextRoll();
  }

  void nextRoll() {
    if (_summary.mine.isEmpty) return;

    diceAnim?.cancel();

    var roll = -1;
    diceAnim = Timer.periodic(Duration(milliseconds: 50), (_) {
      int r;
      do {
        r = rng.nextInt(20) + 1;
      } while (r == roll);

      roll = r;
      initiativeDice.text = '$r';
    });

    var movable = _summary.mine.first;
    var name = movable is EmptyMovable ? movable.label : movable.prefab.name;
    targetText.innerHtml = "<b>$name</b>'s Initiative";

    panel.classes.add('show');
    overlayVisible = true;
  }

  void resetBar() {
    _summary = InitiativeSummary();
    charContainer.children.clear();
    showBar = true;
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
  List<Movable> mine;
  List<InitiativeEntry> entries = [];

  InitiativeSummary() {
    mine = user.session.board.movables.where((m) {
      if (!m.accessible) return false;

      var prefab = m.prefab;
      if (prefab is CustomPrefab) {
        return prefab.accessIds.length == 1;
      }

      return true;
    }).toList();
  }

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
