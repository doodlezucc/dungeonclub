import 'dart:async';
import 'dart:html';
import 'dart:math';

import 'package:dungeonclub/actions.dart';
import 'package:dungeonclub/dice_parser.dart';
import 'package:dungeonclub/iterable_extension.dart';

import '../../main.dart';
import '../communication.dart';
import '../html_helpers.dart';
import 'log.dart';

const maxRolls = 5;

ButtonElement get _button => queryDom('#diceTab');
final TableElement _table = _button.queryDom('table#dice');
final ElementList _visButtons = querySelectorAll('.roll-visibility');

Timer? _rollTimer;

bool _visible = true;
bool get rollPublic => _visible;
set rollPublic(bool public) {
  _visible = public;
  window.localStorage['rollPublic'] = '$public';

  var icon = public ? 'user-group' : 'user-lock';
  for (var btn in _visButtons) {
    btn.queryDom('i').className = 'fas fa-$icon';
    btn.queryDom('span').text = public ? 'Public' : 'Private';
  }
}

int _offset = 0;
int get offset => _offset;
set offset(int offset) {
  _offset = min(max(offset, 0), 20 - maxRolls);
  _table.style.setProperty('--offset', '${_offset + 1}');
}

void _initVisibility() {
  _visButtons.onClick.listen((_) => rollPublic = !rollPublic);
  rollPublic = window.localStorage['rollPublic'] != 'false';
}

void initDiceTable() {
  _initVisibility();
  _initScrollControls();

  void sendSingleRoll(int sides, int repeat) async {
    await sendRollDice(RollCombo([SingleRoll(repeat, sides)]));
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

Future<void> sendRollDice(RollCombo? combo) async {
  if (combo == null || combo.rolls.isEmpty) {
    return;
  }

  if (user.isInDemo) {
    combo.rollAll();
    return onDiceRoll(combo);
  }

  if (_rollTimer != null) return;

  _rollTimer = Timer(Duration(milliseconds: 200), () => _rollTimer = null);

  var results = await socket.request(GAME_ROLL_DICE, {
    ...combo.toJson(),
    'id': user.session!.charId,
    if (user.session!.isDM) 'public': rollPublic,
  });

  onDiceRollJson(results, private: user.session!.isDM && !rollPublic);
}

void onDiceRollJson(Map<String, dynamic> json, {bool private = false}) {
  onDiceRoll(RollCombo.fromJson(json), initiator: json['id'], private: private);
}

void onDiceRoll(RollCombo combo, {int? initiator, bool private = false}) {
  final mine = initiator == user.session!.charId;
  final pc = user.session!.characters.find((e) => e.id == initiator);

  final name = mine ? 'You' : (initiator == null ? 'GM' : pc!.name);

  final resultsExpanded = combo.rolls.expand((r) => r.results!);
  final hasMultipleResults = resultsExpanded.length > 1;

  final showSum = hasMultipleResults || combo.hasMod;

  String suffix;
  if (showSum) {
    final sum = combo.totalResult;
    suffix = '</span><br>= $sum.';
  } else {
    suffix = '.</span>';
  }

  final comboString = _comboToHtml(combo);
  final resultString = _comboResultString(combo);

  gameLog(
    '''$name rolled $comboString
    and got <span>$resultString$suffix''',
    msgType: mine ? msgMine : msgOthers,
    private: private,
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
  String brackets() =>
      roll.openingBracket + results.join(',') + roll.closingBracket;

  var s = (isOnly && !neg && roll.advantage == null) ? loose() : brackets();
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
  if (roll.advantage != null) {
    final picked = roll.result.abs();
    return roll.results!.map((r) {
      final isPicked = r == picked;
      final className = isPicked ? '' : ' ignored';

      return _rollWrap(r, className);
    });
  }

  return roll.results!.map((r) => _resultString(roll.sides, r));
}

String _resultString(int sides, int result) {
  var className = result == sides ? ' good' : (result == 1 ? ' bad' : '');
  return _rollWrap(result, className);
}

String _rollWrap(int x, [String className = '']) {
  return '<span class="roll$className">$x</span>';
}
