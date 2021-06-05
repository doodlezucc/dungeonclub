import 'package:dnd_interactive/actions.dart';

import '../communication.dart';
import 'prefab.dart';

class Character {
  final String name;
  final int id;
  final CharacterPrefab prefab;

  String get img => getGameFile('$IMAGE_TYPE_PC$id', cacheBreak: false);

  Character(this.id, Map<String, dynamic> json)
      : name = json['name'],
        prefab = CharacterPrefab() {
    prefab
      ..fromJson(json['prefab'] ?? {})
      ..character = this;
  }
}
