class Character {
  final String name;

  Character(this.name);

  Character.fromJson(json) : this(json['name']);
}
