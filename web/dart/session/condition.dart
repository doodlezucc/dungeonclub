import 'dart:collection';

class ConditionCategory {
  final String name;
  final LinkedHashMap<int, Condition> conditions;

  ConditionCategory(this.name, Map<int, Condition> conditions)
      : conditions = LinkedHashMap.from(conditions);
}

class Condition {
  static final categories = [perception, movement, physical];
  static final items = {
    ...perception.conditions,
    ...movement.conditions,
    ...physical.conditions,
  };

  static final perception = ConditionCategory('Perception', {
    0: Condition('Blinded', 'low-vision'),
    2: Condition('Deafened', 'deaf'),
    1: Condition('Charmed', 'hand-holding-heart'),
    3: Condition('Frightened', 'spider'),
    12: Condition('Tipsy', 'beer'),
    20: Condition('Confused', 'spinner'),
    19: Condition('Tired', 'moon'),
  });

  static final movement = ConditionCategory('Movement', {
    10: Condition('Prone', 'person-praying'),
    4: Condition('Grappled', 'handshake-angle'),
    14: Condition('Restrained', 'person-cane'),
    18: Condition('Stunned', 'cloud-bolt'),
    7: Condition('Paralyzed', 'male'),
    5: Condition('Incapacitated', 'wheelchair'), // kinda funny
    8: Condition('Petrified', 'snowman'),
  });

  static final physical = ConditionCategory('Spellcasting / Physical', {
    16: Condition('Concentration', 'arrows-to-circle'),
    6: Condition('Invisible', 'ghost'),
    11: Condition('Transformed', 'frog'),
    17: Condition('Levitating', 'dove'),
    9: Condition('Poisoned', 'syringe'),
    15: Condition('Unconscious', 'heart-pulse'),
    13: Condition('Dead', 'skull-crossbones'),
  });

  final String name;
  final String icon;

  const Condition(this.name, this.icon);

  static getConditionById(int id) {
    return items.entries.firstWhere((entry) => entry.key == id).value;
  }
}
