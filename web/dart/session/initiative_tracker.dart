import 'dart:async';
import 'dart:html';
import 'dart:math';

import 'package:dungeonclub/actions.dart';

import '../../main.dart';
import '../communication.dart';
import '../font_awesome.dart';
import '../panels/context_menu.dart';
import '../panels/panel_overlay.dart';
import '../panels/upload.dart';
import 'movable.dart';
import 'prefab.dart';

HtmlElement get initiativeBar => querySelector('#initiativeBar');
HtmlElement get charContainer => initiativeBar.querySelector('.roster');
ButtonElement get rerollButton => querySelector('#initiativeReroll');
InitiativeSummary _summary;

class InitiativeTracker {
  final rng = Random();

  Timer diceAnim;
  Iterable<Movable> _similar;

  ButtonElement get callRollsButton => querySelector('#initiativeTracker');
  SpanElement get initiativeDice => querySelector('#initiativeDice');
  SpanElement get targetText => querySelector('#initiativeTarget');
  ButtonElement get userRollButton => querySelector('#initiativeRoll');
  ButtonElement get skipButton => querySelector('#initiativeSkip');
  ButtonElement get skipTypeButton => querySelector('#initiativeSkipType');
  HtmlElement get panel => querySelector('#initiativePanel');

  bool get rollerPanelVisible => panel.classes.contains('show');
  set showBar(bool v) => initiativeBar.classes.toggle('hidden', !v);
  set disabled(bool disabled) => callRollsButton.disabled = disabled;

  void init(bool isDM) {
    callRollsButton.onClick.listen((_) {
      var trackerActive = callRollsButton.classes.toggle('active');

      if (trackerActive) {
        sendRollForInitiative();
      } else {
        outOfCombat();
        if (!user.session.board.refScene.playing) {
          disabled = true;
        }
        socket.sendAction(GAME_CLEAR_INITIATIVE);
      }
    });

    userRollButton.onClick.listen((_) => rollDice());
    skipButton.classes.toggle('hidden', !isDM);
    skipTypeButton.onClick.listen((_) => _skipAllOfType());
    if (isDM) {
      skipButton.onClick.listen((_) {
        _summary.mine.removeAt(0);
        nextRoll();
      });
      rerollButton.onClick.listen((_) => sendReroll());
      panel.querySelector('.close').onClick.listen((_) {
        _summary.mine.clear();
        nextRoll();
      });
    }
  }

  void sendReroll() {
    _summary.rollRemaining();
    socket.sendAction(GAME_REROLL_INITIATIVE);
    nextRoll();
  }

  void sendRollForInitiative() {
    resetBar();
    _summary.rollRemaining();
    socket.sendAction(GAME_ROLL_INITIATIVE);
    nextRoll();
  }

  void rollDice() {
    diceAnim?.cancel();
    var r = rng.nextInt(20) + 1;
    initiativeDice.text = '$r';

    var movable = _summary.mine.removeAt(0);
    var prefab = movable.prefab;
    var dmOnly = user.session.isDM &&
        (prefab is EmptyPrefab ||
            (prefab is CustomPrefab && prefab.accessIds.isEmpty));

    _summary.registerRoll(movable, r, dmOnly);
    socket.sendAction(
        GAME_ADD_INITIATIVE, {'id': movable.id, 'roll': r, 'dm': dmOnly});

    _disableButtons(true);

    Future.delayed(Duration(milliseconds: 500), () {
      nextRoll();
    });
  }

  void _disableButtons(bool v) {
    skipButton.disabled = userRollButton.disabled = skipTypeButton.disabled = v;
  }

  void addToInBar(Map<String, dynamic> json) {
    int id = json['id'];
    int total = json['roll'];
    int mod = json['mod'];
    bool dm = json['dm'] ?? false;
    for (var movable in user.session.board.movables) {
      if (id == movable.id) {
        return _summary.registerRoll(movable, total, dm, mod);
      }
    }
  }

  void reroll() {
    _summary.rollRemaining();
    if (!rollerPanelVisible) {
      nextRoll();
    }
  }

  void showRollerPanel() {
    resetBar();
    _summary.rollRemaining();
    nextRoll();
  }

  void nextRoll() {
    if (_summary.mine.isEmpty) {
      if (panel.classes.remove('show')) overlayVisible = false;
      return;
    }

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

    var mv = _summary.mine.first;
    var prefab = mv.prefab;
    _similar = _summary.mine.where((other) {
      if (mv is EmptyMovable) {
        return other is EmptyMovable && mv.label == other.label;
      }
      return other.prefab == prefab;
    });

    var name = mv.displayName;
    targetText.innerHtml = "<b>$name</b>'s Initiative";

    skipTypeButton.text = 'Skip ${_similar.length} Similar Tokens';
    skipTypeButton.classes.toggle('hidden', _similar.length < 2);

    if (panel.classes.add('show')) overlayVisible = true;
    _disableButtons(false);
  }

  void _skipAllOfType() {
    if (_similar != null) {
      _summary.mine.removeWhere((m) => _similar.contains(m));
      nextRoll();
    }
  }

  void resetBar() {
    _summary = InitiativeSummary();
    showBar = true;
  }

  void outOfCombat() {
    showBar = false;
    _summary?.entries?.forEach((entry) => entry.e.remove());
    _summary = null;
    updateRerollableInitiatives();
    if (panel.classes.remove('show')) overlayVisible = false;
  }

  void onNameUpdate(Movable m) {
    if (_summary != null) {
      for (var entry in _summary.entries) {
        if (entry.movable == m) {
          entry.nameText.text = m.displayName;
          return;
        }
      }
    }
  }

  void onRemoveID(int mid) {
    if (_summary != null) {
      for (var entry in _summary.entries.toList()) {
        if (entry.movable.id == mid) {
          return _summary.removeEntry(entry);
        }
      }
    }
  }

  void onRemove(Movable m) {
    if (_summary != null) {
      for (var entry in _summary.entries.toList()) {
        if (entry.movable == m) {
          return _summary.removeEntry(entry);
        }
      }
      updateRerollableInitiatives();
    }
  }

  void onUpdate(Map<String, dynamic> json) {
    int id = json['id'];
    int mod = json['mod'];
    for (var entry in _summary.entries) {
      if (entry.movable.id == id) {
        var prefab = entry.movable.prefab;
        if (prefab is HasInitiativeMod) prefab.initiativeMod = mod;

        entry.modifier = mod;
        return _summary.sort();
      }
    }
  }

  void fromJson(Iterable jList) {
    callRollsButton.classes.toggle('active', jList != null);
    outOfCombat();
    if (jList != null) {
      resetBar();
      for (var j in jList) {
        addToInBar(j);
      }
      disabled = false;
    }
  }
}

bool canReroll() {
  if (_summary == null) return true;
  var board = user.session.board;
  for (var m in board.movables) {
    if (!_summary.entries.any((e) => e.movable == m)) {
      return true;
    }
  }
  return false;
}

void updateRerollableInitiatives() {
  if (user.session.isDM) {
    rerollButton.disabled = !canReroll();
  }
}

class InitiativeSummary {
  final List<Movable> mine = [];
  List<InitiativeEntry> entries = [];

  static int _importance(Movable m) {
    var p = m.prefab;
    if (p is CharacterPrefab) return 0;
    if (p is CustomPrefab) return 1;
    if (p is EmptyPrefab) return 2;
    return 3;
  }

  void rollRemaining() {
    var isDm = user.session.isDM;
    mine.addAll(user.session.board.movables.where((m) {
      if (entries.any((e) => e.movable == m) || mine.contains(m)) return false;

      var prefab = m.prefab;

      if (isDm) {
        if (prefab is CharacterPrefab) {
          return !prefab.character.hasJoined;
        }
      } else if (!m.accessible) {
        return false;
      }

      if (prefab is CustomPrefab) {
        var controllers = user.session.characters.where((pc) {
          return pc.hasJoined && prefab.accessIds.contains(pc.id);
        });

        // DM has control unless exactly one player who has access to
        // this token is currently in the session.
        return isDm == (controllers.length != 1);
      }

      return true;
    }));
    mine.sort((a, b) {
      var cmp = _importance(a).compareTo(_importance(b));

      if (cmp == 0) return a.name.compareTo(b.name);

      return cmp;
    });
  }

  void removeEntry(InitiativeEntry entry) {
    entry.e.remove();
    entries.remove(entry);
    updateRerollableInitiatives();
  }

  void registerRoll(Movable movable, int base, bool dmOnly, [int mod]) {
    var entry = InitiativeEntry(movable, base, dmOnly);
    if (mod != null) entry.modifier = mod;

    entries.add(entry);
    charContainer.append(entry.e);
    sort();
    updateRerollableInitiatives();
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
    charContainer.append(rerollButton);
  }
}

class InitiativeEntry {
  final e = DivElement();
  final modText = SpanElement();
  final totalText = SpanElement();
  final nameText = SpanElement()..className = 'compact';
  final Movable movable;
  final int base;

  bool get dmOnly => e.classes.contains('private');
  set dmOnly(bool dmOnly) {
    if (user.session.isDM) {
      e.classes.toggle('private', dmOnly);
    }
  }

  int get total => base + modifier;

  int _modifier;
  int get modifier => _modifier;
  set modifier(int modifier) {
    _modifier = modifier;
    modText.text = (modifier >= 0 ? '+$modifier' : '$modifier');
    totalText.text = '$total';

    var pref = movable.prefab;
    if (pref is HasInitiativeMod) {
      pref.initiativeMod = modifier;
    }
  }

  InitiativeEntry(this.movable, this.base, bool dmOnly) {
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
        ..append(totalText)
        ..onLMB.listen(_onClick)
        ..onContextMenu.listen(_onClick))
      ..append(nameText..text = movable.displayName)
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

    this.dmOnly = dmOnly;
    var pref = movable.prefab;
    if (pref is HasInitiativeMod) {
      modifier = pref.initiativeMod;
    } else {
      modifier = 0;
    }
  }

  void _onClick(MouseEvent ev) async {
    ev.preventDefault();
    if (!user.session.isDM) return;

    if (e.classes.contains('hide')) {
      e.classes.remove('hide');
      return;
    }

    var menu = ContextMenu()
      ..addButton(dmOnly ? 'Show' : 'Hide', dmOnly ? 'eye' : 'eye-slash')
      ..addButton('Remove', 'trash');

    var result = await menu.display(ev, e.querySelector('div'));
    if (result == null) return;

    switch (result) {
      case 0:
        dmOnly = !dmOnly;
        sendUpdate();
        return;
      case 1:
        await socket.sendAction(GAME_REMOVE_INITIATIVE, {'id': movable.id});
        return _summary.removeEntry(this);
    }
  }

  void sendUpdate() {
    if (user.session.isDM) {
      socket.sendAction(GAME_UPDATE_INITIATIVE, {
        'id': movable.id,
        'mod': modifier,
        'dm': dmOnly,
      });
    }
  }
}
