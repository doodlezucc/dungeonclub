import 'dart:async';
import 'dart:html';
import 'dart:math';

import 'package:dnd_interactive/actions.dart';
import 'package:dnd_interactive/dice_parser.dart';

import '../../main.dart';
import '../communication.dart';
import '../formatting.dart';
import 'log.dart';

ButtonElement get _button => querySelector('#diceTab');
final TableElement _table = _button.querySelector('table#dice');
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

  void sendSingleRoll(int sides, int repeat) async {
    await sendRollDice(RollCombo([SingleRoll(repeat, sides)]));

    if (isMobile) {
      _button.classes.remove('hovered');
    }
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
  _button.onMouseEnter.listen((_) {
    offset = 0;
  });
}

Future<void> sendRollDice(RollCombo combo) async {
  if (combo?.rolls?.isEmpty ?? true) return;

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

  var allResults = combo.rolls.expand((r) => r.resultsSigned);

  var sum = allResults.fold(0, (x, roll) => x + roll) + combo.modifier;
  var showSum = allResults.length > 1 || combo.hasMod;
  var sumString = !showSum ? '.</span>' : '</span><br>= $sum.';

  var comboString = _comboToHtml(combo);
  var resultString = _comboResultString(combo);

  gameLog(
    '''$name rolled $comboString
    and got <span>$resultString$sumString''',
    msgType: mine ? msgMine : msgOthers,
  );
}

String _comboToHtml(RollCombo combo) {
  return wrapAround(combo.toCommandString(), 'span', 'dice');
}

String _singleRollString(SingleRoll roll,
    {bool isFirst = false, bool isOnly = false}) {
  var neg = roll.repeat.isNegative;
  var results = _rollStrings(roll);

  String loose() => results.join(' + ');
  String brackets() => '(' + results.join(',') + ')';

  var s = (isOnly && !neg) ? loose() : brackets();
  if (neg) {
    var sign = '-';
    if (!isFirst) sign += ' ';

    s = '$sign$s';
  } else if (!isFirst) {
    s = '+ $s';
  }

  return s;
}

String _comboResultString(RollCombo combo) {
  var joinedResults = _singleRollString(
    combo.rolls.first,
    isFirst: true,
    isOnly: combo.rolls.length == 1 && !combo.hasMod,
  );

  joinedResults +=
      combo.rolls.skip(1).map((e) => ' ' + _singleRollString(e)).join('');

  if (combo.hasMod) {
    var mod = combo.modifier;
    joinedResults += (mod.isNegative ? ' - ' : ' + ');
    joinedResults += _rollWrap(mod.abs());
  }

  return joinedResults;
}

Iterable<String> _rollStrings(SingleRoll roll) {
  return roll.results.map((r) => _resultString(roll.sides, r));
}

String _resultString(int sides, int result) {
  var className = result == sides ? ' good' : (result == 1 ? ' bad' : '');
  return _rollWrap(result, className);
}

String _rollWrap(int x, [String className = '']) {
  return '<span class="roll$className">$x</span>';
}
