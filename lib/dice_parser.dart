import 'dart:math';

class DiceParser {
  static final cmdRegex = RegExp(r'([+\-\s]|d?\d)+');

  static bool isCommand(String msg) {
    var matches = cmdRegex.allMatches(msg.toLowerCase());
    return matches.where((s) => s[0].trim().isNotEmpty).length == 1;
  }

  static RollCombo parse(String s) {
    var rolls = <SingleRoll>[];
    var mod = 0;

    var matches = SingleRoll.regex.allMatches(s);

    for (var match in matches) {
      var part = match[0].replaceAll(' ', '');

      if (part.contains('d')) {
        var parsed = SingleRoll.parse(part);
        if (parsed != null) rolls.add(parsed);
      } else {
        mod += int.tryParse(part) ?? 0;
      }
    }

    if (rolls.isEmpty) return null;

    return RollCombo(rolls, mod);
  }
}

class SingleRoll {
  /// Allows for rolls (5d4, d20) and modifiers, respecting negative signs
  static final regex = RegExp(r'((-\s*)?\d*(d\d+))|((-\s*)?\d+)');
  final int repeat;
  final int sides;
  Iterable<int> results;
  String get name => '${repeat}d$sides';
  String get nameAbs => '${repeat.abs()}d$sides';
  Iterable<int> get resultsSigned {
    if (!repeat.isNegative) return results;
    return results.map((x) => -x);
  }

  SingleRoll(this.repeat, this.sides, [this.results]);

  static SingleRoll parse(String s) {
    var dIndex = s.indexOf('d');
    var pre = s.substring(0, dIndex);
    var repeat = int.tryParse(pre) ?? 1;
    var suf = s.substring(dIndex + 1);
    var sides = int.tryParse(suf);

    if (sides != null && sides > 0) {
      return SingleRoll(repeat, sides);
    }

    return null;
  }

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
}

class RollCombo {
  static final rng = Random();

  final List<SingleRoll> rolls;
  final int modifier;
  bool get hasResults => rolls.isEmpty ? false : rolls.first.results != null;
  bool get hasMod => modifier != 0;

  RollCombo(this.rolls, [this.modifier = 0]);

  List<int> _roll(int sides, int repeat) {
    return List.generate(repeat.abs(), (i) => rng.nextInt(sides) + 1);
  }

  void rollAll() {
    rolls.forEach((r) => r.results = _roll(r.sides, r.repeat));
  }

  String toCommandString() {
    if (rolls.isEmpty) return modifier.toString();

    String signString(int x) {
      var neg = x.isNegative;
      return neg ? ' - ' : ' + ';
    }

    var first = rolls.first;
    var s = first.repeat.isNegative ? '-' : '';
    s += first.nameAbs;

    s += rolls.skip(1).map((r) {
      var part = signString(r.repeat);
      return '$part${r.nameAbs}';
    }).join('');

    if (hasMod) {
      var sign = signString(modifier);
      s += '$sign${modifier.abs()}';
    }

    return s;
  }

  static RollCombo fromJson(Map<String, dynamic> json) => RollCombo(
        (json['rolls'] as Iterable).map((j) => SingleRoll.fromJson(j)).toList(),
        json['mod'],
      );

  Map<String, dynamic> toJson() =>
      {'rolls': rolls.map((e) => e.toJson()).toList(), 'mod': modifier};
}
