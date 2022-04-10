import 'dart:async';
import 'dart:html';
import 'dart:math';

import 'package:dnd_interactive/actions.dart';
import 'package:dnd_interactive/dice_parser.dart';

import '../../main.dart';
import '../communication.dart';
import '../formatting.dart';
import 'log.dart';

final TableElement _table = querySelector('table#dice');
bool _visible = true;
Timer _rollTimer;

const maxRolls = 5;

int _offset = 0;
int get offset => _offset;
set offset(int offset) {
  _offset = min(max(offset, 0), 20 - maxRolls);
  _table.style.setProperty('--offset', '${_offset + 1}');
}

void _initVisibility() {
  var button = _table.parent.querySelector('span');

  void update() {
    var icon = _visible ? 'eye' : 'eye-slash';
    button.querySelector('i').className = 'fas fa-$icon';
    button.querySelector('span').text = _visible ? 'All Players' : 'Only You';
  }

  button.onClick.listen((_) {
    _visible = !_visible;
    update();
  });
  update();
}

void initDiceTable() {
  _initVisibility();
  _initScrollControls();

  void sendSingleRoll(int sides, int repeat) {
    sendRollDice(RollCombo([SingleRoll(repeat, sides)]));
  }

  [4, 6, 8, 10, 12, 20, 100].forEach((sides) {
    var row = TableRowElement();
    row.append(TableCellElement()
      ..text = 'd$sides'
      ..onClick.listen((_) => sendSingleRoll(sides, 1)));

    for (var i = 2; i <= maxRolls; i++) {
      row.append(TableCellElement()
        ..onClick.listen((_) => sendSingleRoll(sides, i + offset)));
    }
    _table.append(row);
  });
}

void _initScrollControls() {
  _table.onMouseWheel.listen((ev) {
    offset -= ev.deltaY.sign.toInt();
  });
  querySelector('#diceTab').onMouseEnter.listen((_) {
    offset = 0;
  });
}

Future<void> sendRollDice(RollCombo combo) async {
  if (user.isInDemo) {
    combo.rollAll();
    return onDiceRoll(combo);
  }

  if (_rollTimer != null) return;

  _rollTimer = Timer(Duration(milliseconds: 200), () => _rollTimer = null);

  var results = await socket.request(GAME_ROLL_DICE, {
    ...combo.toJson(),
    'id': user.session.charId,
    if (user.session.isDM) 'public': _visible,
  });

  onDiceRollJson(results);
}

void onDiceRollJson(Map<String, dynamic> json) {
  onDiceRoll(RollCombo.fromJson(json), initiator: json['id']);
}

void onDiceRoll(RollCombo combo, {int initiator}) {
  var mine = initiator == user.session.charId;

  var name = mine
      ? 'You'
      : (initiator == null ? 'GM' : user.session.characters[initiator].name);

  var resultString = _comboResultString(combo);

  var allResults = combo.rolls.expand((r) => r.results);

  var sum = allResults.fold(0, (x, roll) => x + roll) + combo.modifier;
  var sumString = allResults.length == 1 ? '.</span>' : '</span><br>= $sum.';

  var comboString = _comboToHtml(combo);

  gameLog('''
    $name rolled $comboString
    and got <span>$resultString$sumString''', mine: mine);
}

String _comboToHtml(RollCombo combo) {
  return wrapAround(
    [
      ...combo.rolls.map((e) => e.name),
      if (combo.hasMod) '${combo.modifier}',
    ].join(' + '),
    'span',
    'dice',
  );
}

String _comboResultString(RollCombo combo) {
  dynamic results = _rollStrings(combo.rolls.first).join(' + ');

  if (combo.rolls.length > 1) {
    results = combo.rolls.map((r) => _rollStrings(r)).join(' + ');
  }

  return [
    results,
    if (combo.hasMod) _rollWrap(combo.modifier),
  ].join(' + ');
}

Iterable<String> _rollStrings(SingleRoll roll) {
  return roll.results.map((r) => _resultString(roll.sides, r));
}

String _resultString(int sides, int result) {
  var className = result == 1 ? ' bad' : (result == sides ? ' good' : '');
  return _rollWrap(result, className);
}

String _rollWrap(int x, [String className = '']) {
  return '<span class="roll$className">$x</span>';
}
