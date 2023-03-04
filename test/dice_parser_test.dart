import 'package:dungeonclub/dice_parser.dart';
import 'package:test/test.dart';

void main() {
  test('Single dice roll', () {
    expectedDiceParse('d19', [SingleRoll(1, 19)]);
  });

  test('Repeated single dice roll', () {
    expectedDiceParse('4d19', [SingleRoll(4, 19)]);
  });
}

void expectedDiceParse(
  String input,
  List<SingleRoll> expectedRolls, [
  int expectedModifier = 0,
]) {
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
