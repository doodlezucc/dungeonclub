class Character {
  final String name;

  Character(this.name);

  Character.fromJson(json) : this(json['name']);
}

class MyCharacter extends Character {
  MyCharacter(String name) : super(name);

  MyCharacter.fromJson(json) : this(json['name']);
}
