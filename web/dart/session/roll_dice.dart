import 'dart:html';

import 'package:dnd_interactive/actions.dart';

import '../communication.dart';

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
  var results = await socket
      .request(GAME_ROLL_DICE, {'dice': List.filled(repeat, sides)});

  print(results);
}

void onDiceRoll(Map<String, dynamic> json) {
  print(json);
}
