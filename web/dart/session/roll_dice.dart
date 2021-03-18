import 'dart:html';

import 'package:dnd_interactive/actions.dart';

import '../../main.dart';
import '../communication.dart';
import 'log.dart';

final TableElement _table = querySelector('table#dice');

void initDiceTable() {
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
  });

  onDiceRoll(results);
}

void onDiceRoll(Map<String, dynamic> json) {
  var initiator = json['id'];
  int sides = json['sides'];
  var rolls = List.from(json['results'] ?? []);

  var name =
      initiator == null ? 'You' : user.session.characters[initiator].name;

  var results = rolls.map((r) => _resultString(sides, r)).join(', ');
  gameLog('''
    $name rolled <span class="dice d$sides">${rolls.length}d$sides</span>
    and got <span>$results.</span>''');
}

String _resultString(int sides, int result) {
  var className = result == 1 ? ' bad' : (result == sides ? ' good' : '');
  return '<span class="roll$className">$result</span>';
}
