import 'dart:math';

class DiceParser {
  static bool isCommand(String msg) {
    return msg.trimLeft().startsWith('/r');
  }

  static RollCombo parse(String s) {
    var parts = s.trim().split(' ');
    var rolls = <SingleRoll>[];

    var mod = 0;

    for (var part in parts) {
      var match = SingleRoll.regex.firstMatch(part);
      if (match == null) {
        print('Unable to match $part');
        mod += int.tryParse(part) ?? 0;
      } else {
        var parsed = SingleRoll.parse(match[0]);
        if (parsed != null) rolls.add(parsed);
      }
    }

    if (rolls.isEmpty) return null;

    return RollCombo(rolls, mod);
  }
}

class SingleRoll {
  static final regex = RegExp(r'\d*d\d+');
  final int repeat;
  final int sides;
  Iterable<int> results;
  String get name => '${repeat}d$sides';

  SingleRoll(this.repeat, this.sides, [this.results]);

  SingleRoll.fromJson(Map<String, dynamic> json)
      : repeat = json['repeat'],
        sides = json['sides'] {
    if (json['results'] != null) {
      results = List.from(json['results']);
    }
  }

  Map<String, dynamic> toJson() => {
        'repeat': repeat,
        'sides': sides,
        if (results != null) 'results': results.toList()
      };

  static SingleRoll parse(String s) {
    var dIndex = s.indexOf('d');
    var pre = s.substring(0, dIndex);
    var repeat = int.tryParse(pre) ?? 1;
    var suf = s.substring(dIndex + 1);
    var sides = int.tryParse(suf);

    if (sides != null) {
      return SingleRoll(repeat, sides);
    }

    return null;
  }
}

class RollCombo {
  static final rng = Random();

  final List<SingleRoll> rolls;
  final int modifier;
  bool get hasResults => rolls.isEmpty ? false : rolls.first.results != null;
  bool get hasMod => modifier != 0;

  RollCombo(this.rolls, [this.modifier = 0]);

  List<int> _roll(int sides, int repeat) {
    return List.generate(repeat, (i) => rng.nextInt(sides) + 1);
  }

  void rollAll() {
    rolls.forEach((r) => r.results = _roll(r.sides, r.repeat));
  }

  static RollCombo fromJson(Map<String, dynamic> json) => RollCombo(
        (json['rolls'] as Iterable).map((j) => SingleRoll.fromJson(j)).toList(),
        json['mod'],
      );

  Map<String, dynamic> toJson() =>
      {'rolls': rolls.map((e) => e.toJson()).toList(), 'mod': modifier};
}
