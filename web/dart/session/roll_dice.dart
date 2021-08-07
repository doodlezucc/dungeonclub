import 'dart:html';

import 'package:dnd_interactive/actions.dart';

import '../../main.dart';
import '../communication.dart';
import 'log.dart';

final TableElement _table = querySelector('table#dice');
bool _visible = true;

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

  var maxRolls = 5;

  [4, 6, 8, 10, 12, 20, 100].forEach((sides) {
    var row = TableRowElement();
    row.append(TableCellElement()
      ..text = 'd$sides'
      ..onClick.listen((_) => _rollDice(sides, 1)));

    for (var i = 2; i <= maxRolls; i++) {
      row.append(TableCellElement()
        ..text = '$i'
        ..onClick.listen((_) => _rollDice(sides, i)));
    }
    _table.append(row);
  });
}

Future<void> _rollDice(int sides, int repeat) async {
  var results = await socket.request(GAME_ROLL_DICE, {
    'sides': sides,
    'repeat': repeat,
    'id': user.session.charId,
    if (user.session.isDM) 'public': _visible,
  });

  onDiceRoll(results);
}

void onDiceRoll(Map<String, dynamic> json) {
  int initiator = json['id'];
  int sides = json['sides'];
  var rolls = List.from(json['results'] ?? []);

  var mine = initiator == null || initiator == user.session.charId;

  var name = mine ? 'You' : user.session.characters[initiator].name;

  var results = rolls.map((r) => _resultString(sides, r)).join(' + ');

  var sum = rolls.fold(0, (x, roll) => x + roll);
  var sumString = rolls.length == 1 ? '.</span>' : '</span><br>= $sum.';

  gameLog('''
    $name rolled <span class="dice d$sides">${rolls.length}d$sides</span>
    and got <span>$results$sumString''', mine: mine);
}

String _resultString(int sides, int result) {
  var className = result == 1 ? ' bad' : (result == sides ? ' good' : '');
  return '<span class="roll$className">$result</span>';
}
