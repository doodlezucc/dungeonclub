import 'dart:math';

const DEFAULT_DICE_SIDES = 20;
const MAX_DICE_REPEATS = 100;
const MAX_DICE_SIDES = 1000000;

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

    var matches = SingleRoll.regex.allMatches(s.toLowerCase());

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
        final parsed = SingleRoll.parse(match);
        if (parsed != null) {
          rolls.add(parsed);
        }
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

  String get _prefix => advantage == null ? '$repeat' : '';
  String get _prefixAbs => advantage == null ? '${repeat.abs()}' : '';
  String get _advantageSuffix =>
      advantage == null ? '' : (advantage ? 'adv' : 'dis');

  String get name => '${_prefix}d$sides$_advantageSuffix';
  String get nameAbs => '${_prefixAbs}d$sides$_advantageSuffix';

  String get openingBracket =>
      advantage == null ? '(' : (advantage ? '⌈' : '⌊');

  String get closingBracket =>
      advantage == null ? ')' : (advantage ? '⌉' : '⌋');

  int get _resultAbs {
    if (advantage == null) {
      return results.fold(0, (x, result) => x + result);
    }

    if (advantage) {
      return results.fold(0, (x, result) => max(x, result));
    } else {
      return results.fold(sides, (x, result) => min(x, result));
    }
  }

  int get result {
    if (repeat.isNegative) {
      return -_resultAbs;
    } else {
      return _resultAbs;
    }
  }

  SingleRoll(this.repeat, this.sides, {this.results, this.advantage});

  static SingleRoll parse(RegExpMatch match) {
    final isNegated = match[1] != null;
    final sign = isNegated ? -1 : 1;

    final defAdvantage = match[7];

    if (defAdvantage != null) {
      final isAdvPositive = defAdvantage.startsWith('a');
      return SingleRoll(sign, DEFAULT_DICE_SIDES, advantage: isAdvPositive);
    }

    final sides = int.parse(match[2] ?? match[5]);
    final advantageMatch = match[3];

    if (advantageMatch != null) {
      final isAdvPositive = advantageMatch.startsWith('a');
      return SingleRoll(sign, sides, advantage: isAdvPositive);
    }

    final repeat = match[4].isNotEmpty ? int.parse(match[4]) : 1;

    if (sides > 0 && repeat <= MAX_DICE_REPEATS && sides <= MAX_DICE_SIDES) {
      return SingleRoll(sign * repeat, sides);
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

  @override
  String toString() => name;

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

  int get rollsResult => rolls.fold(0, (x, roll) => x + roll.result);
  int get totalResult => rollsResult + modifier;

  bool get hasResults => rolls.isEmpty ? false : rolls.first.results != null;
  bool get hasMod => modifier != 0;

  RollCombo(this.rolls, [this.modifier = 0]);

  static List<int> _roll(int sides, int repeat) {
    return List.generate(repeat.abs(), (i) => rng.nextInt(sides) + 1);
  }

  static void _computeRoll(SingleRoll roll) {
    var repeat = roll.repeat;
    if (roll.advantage != null) {
      repeat = 2;
    }

    roll.results = _roll(roll.sides, repeat);
  }

  void rollAll() {
    rolls.forEach((roll) => _computeRoll(roll));
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
