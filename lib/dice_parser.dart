import 'dart:math';

const ADVANTAGE_DICE_SIDES = 20;

class DiceParser {
  static final cmdRegex =
      RegExp(r'([+\-\s]|d\d+(a\w*|d\w*)?|\d+|(adv(antage)?|dis(advantage)?))+');

  static bool isCommand(String msg) {
    final matches = cmdRegex.allMatches(msg.toLowerCase());

    return matches.length == 1 &&
        matches.first.start == 0 &&
        matches.first.end == msg.length;
  }

  static RollCombo parse(String s) {
    var rolls = <SingleRoll>[];
    var mod = 0;

    var matches = SingleRoll.regex.allMatches(s);

    for (var match in matches) {
      if (match[6] != null) {
        // Match is number/modifier
        final number = int.parse(match[6]);

        // match[1] means negation
        if (match[1] != null) {
          mod -= number;
        } else {
          mod += number;
        }
      } else {
        // Match is dice roll
        rolls.add(SingleRoll.parse(match));
      }
    }

    if (rolls.isEmpty) return null;

    return RollCombo(rolls, mod);
  }
}

class SingleRoll {
  /// [1] - IF NOT NULL: negate this number/roll
  ///
  /// SPECIFIC DICE WITH ADVANTAGE OR DISADVANTAGE
  /// [2] - number of dice sides
  /// [3] - [a]dvantage or [d]isadvantage
  ///
  /// (REPEATED) DICE ROLL
  /// [4] - repetitions of this dice
  /// [5] - number of dice sides
  ///
  /// NUMBER
  /// [6] - this number
  ///
  /// DEFAULT ADVANTAGE OR DISADVANTAGE
  /// [7] - full adv/dis string
  static final regex =
      RegExp(r'(-\s*)?(?:d(\d+)(a\w*|d\w*)|(\d*)d(\d+)|(\d+)|(adv\w*|dis\w*))');

  final int repeat;
  final int sides;
  final bool advantage; // null <=> no advantage or disadvantage

  Iterable<int> results;
  String get name => '${repeat}d$sides';
  String get nameAbs => '${repeat.abs()}d$sides';
  Iterable<int> get resultsSigned {
    if (!repeat.isNegative) return results;
    return results.map((x) => -x);
  }

  SingleRoll(this.repeat, this.sides, {this.results, this.advantage});

  static SingleRoll parse(RegExpMatch match) {
    final isNegated = match[1] != null;
    final sign = isNegated ? -1 : 1;

    final defAdvantage = match[7];

    if (defAdvantage != null) {
      final isAdvPositive = defAdvantage.startsWith('a');
      return SingleRoll(sign, ADVANTAGE_DICE_SIDES, advantage: isAdvPositive);
    }

    final sides = int.parse(match[2] ?? match[5]);
    final advantageMatch = match[3];

    if (advantageMatch != null) {
      final isAdvPositive = advantageMatch.startsWith('a');
      return SingleRoll(1, sides, advantage: isAdvPositive);
    }

    final repeat = match[4].isNotEmpty ? int.parse(match[4]) : 1;

    if (sides > 0 && repeat <= 1000 && sides <= 1000000) {
      return SingleRoll(repeat, sides);
    }

    return null;
  }

  @override
  bool operator ==(other) {
    if (other is SingleRoll) {
      return other.repeat == repeat &&
          other.sides == sides &&
          other.advantage == advantage;
    }

    return false;
  }

  String get _advantageSuffix =>
      advantage == null ? '' : (advantage ? 'adv' : 'dis');

  @override
  String toString() => '${repeat}d$sides$_advantageSuffix';

  SingleRoll.fromJson(Map<String, dynamic> json)
      : repeat = json['repeat'],
        sides = json['sides'],
        advantage = json['advantage'] {
    if (json['results'] != null) {
      results = List.from(json['results']);
    }
  }

  Map<String, dynamic> toJson() => {
        'repeat': repeat,
        'sides': sides,
        'advantage': advantage,
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
