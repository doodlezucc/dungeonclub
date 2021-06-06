class Condition {
  // Order based on https://roll20.net/compendium/dnd5e/Conditions#content
  static const items = [
    Condition('Blinded', 'low-vision'),
    Condition('Charmed', 'hand-holding-heart'),
    Condition('Deafened', 'deaf'),
    Condition('Frightened', 'flushed'), // lmao
    Condition('Grappled', 'link'),
    Condition('Incapacitated', 'wheelchair'), // also kinda funny
    Condition('Invisible', 'ghost'),
    Condition('Paralyzed', 'male'),
    Condition('Petrified', 'cube'),
    Condition('Poisoned', 'syringe'),
    Condition('Prone', 'hiking'),
    Condition('Transformed', 'frog'),
    Condition('Tipsy', 'beer'),
    Condition('Dead', 'skull-crossbones'),
  ];

  final String name;
  final String icon;

  const Condition(this.name, this.icon);
}
