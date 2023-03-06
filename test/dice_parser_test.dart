import 'package:dungeonclub/dice_parser.dart';
import 'package:test/test.dart';

void main() {
  test('Single dice roll', () {
    expectDiceParse('d19', [SingleRoll(1, 19)]);
  });

  test('Repeated single dice roll', () {
    expectDiceParse('4d19', [SingleRoll(4, 19)]);
  });

  test('Negative single dice roll', () {
    expectDiceParse('-d19', [SingleRoll(-1, 19)]);
  });

  test('Negative repeated single dice roll', () {
    expectDiceParse('-4d19', [SingleRoll(-4, 19)]);
  });

  test('Single dice roll with positive single modifier', () {
    expectDiceParse('d19 + 17', [SingleRoll(1, 19)], 17);
  });

  test('Single dice roll with negative single modifier', () {
    expectDiceParse('d19 - 17', [SingleRoll(1, 19)], -17);
  });

  test('Single dice roll with combined modifier', () {
    expectDiceParse('d19 - 17 + 12 - 3', [SingleRoll(1, 19)], -8);
  });

  test('Single dice roll with modifier in front', () {
    expectDiceParse('-17 + 12 - 3 + d19', [SingleRoll(1, 19)], -8);
  });

  test('Two dice rolls', () {
    expectDiceParse('d19 + d17', [SingleRoll(1, 19), SingleRoll(1, 17)]);
    expectDiceParse('d19 - d17', [SingleRoll(1, 19), SingleRoll(-1, 17)]);
    expectDiceParse('d17 - d19', [SingleRoll(1, 17), SingleRoll(-1, 19)]);
    expectDiceParse('-d17 - d19', [SingleRoll(-1, 17), SingleRoll(-1, 19)]);
  });

  const defDice = DEFAULT_DICE_SIDES;

  test('Default advantage/disadvantage', () {
    expectFailure('a');
    expectFailure('ad');
    expectDiceParse('adv', [SingleRoll(1, defDice, advantage: true)]);
    expectFailure('adva');
    expectFailure('advantag');
    expectDiceParse('advantage', [SingleRoll(1, defDice, advantage: true)]);
    expectFailure('advantagee');

    expectFailure('d');
    expectFailure('di');
    expectDiceParse('dis', [SingleRoll(1, defDice, advantage: false)]);
    expectFailure('disa');
    expectFailure('disadvantag');
    expectDiceParse('disadvantage', [SingleRoll(1, defDice, advantage: false)]);
    expectFailure('disadvantagee');
  });

  test('Negated advantage/disadvantage', () {
    expectDiceParse('-adv', [SingleRoll(-1, defDice, advantage: true)]);
    expectDiceParse('-dis', [SingleRoll(-1, defDice, advantage: false)]);
  });

  test('Explicitly sided dice roll with advantage', () {
    expectDiceParse('d15a', [SingleRoll(1, 15, advantage: true)]);
    expectDiceParse('d16ad', [SingleRoll(1, 16, advantage: true)]);
    expectDiceParse('d17adv', [SingleRoll(1, 17, advantage: true)]);
    expectDiceParse('d18adva', [SingleRoll(1, 18, advantage: true)]);

    expectDiceParse('d1d', [SingleRoll(1, 1, advantage: false)]);
    expectDiceParse('d7di', [SingleRoll(1, 7, advantage: false)]);
    expectDiceParse('d13disadvantage', [SingleRoll(1, 13, advantage: false)]);
  });

  test('Negated explicitly sided dice roll with advantage', () {
    expectDiceParse('-d15a', [SingleRoll(-1, 15, advantage: true)]);
    expectDiceParse('-  d16adv', [SingleRoll(-1, 16, advantage: true)]);

    expectDiceParse('- d1d', [SingleRoll(-1, 1, advantage: false)]);
    expectDiceParse('-d13disadvantage', [SingleRoll(-1, 13, advantage: false)]);
  });

  test('Ignore advantage in repeated dice rolls', () {
    expectDiceParse('2d19a', [SingleRoll(2, 19)]);
    expectDiceParse('3d19a', [SingleRoll(3, 19)]);
    expectDiceParse('-7d19a', [SingleRoll(-7, 19)]);
    expectDiceParse('2d19d', [SingleRoll(2, 19)]);

    // Allow explicit "1" (one roll) before advantage roll syntax?
    // expectDiceParse('1d19d', [SingleRoll(1, 19, advantage: true)]);
  });

  test('Complex dice roll', () {
    expectDiceParse(
        'd20adv + 5 - 2d6 - 7',
        [
          SingleRoll(1, 20, advantage: true),
          SingleRoll(-2, 6),
        ],
        -2);

    expectDiceParse(
        '8 - disadvantage - d20adv + 4d3 - 3 - 3 + 5',
        [
          SingleRoll(-1, defDice, advantage: false),
          SingleRoll(-1, 20, advantage: true),
          SingleRoll(4, 3),
        ],
        7);
  });
}

void expectFailure(String input) {
  final isCommand = DiceParser.isCommand(input);
  if (isCommand) {
    expect(DiceParser.parse(input), isNull);
  } else {
    expect(isCommand, false);
  }
}

void expectDiceParse(
  String input,
  List<SingleRoll> expectedRolls, [
  int expectedModifier = 0,
]) {
  expect(DiceParser.isCommand(input), isTrue);
  expect(DiceParser.parse(input), rollMatcher(expectedRolls, expectedModifier));
}

Matcher rollMatcher(
  List<SingleRoll> expectedRolls, [
  int expectedModifier = 0,
]) {
  return isA<RollCombo>()
      .having((rc) => rc.rolls, 'Rolls', unorderedEquals(expectedRolls))
      .having((rc) => rc.modifier, 'Modifier', equals(expectedModifier));
}
