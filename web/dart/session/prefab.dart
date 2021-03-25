import 'dart:html';

import 'package:dnd_interactive/actions.dart';
import 'package:meta/meta.dart';

import '../communication.dart';
import 'character.dart';
import 'prefab_palette.dart';

abstract class EntityBase {
  int _size;
  int get size => _size;
  set size(int size) {
    _size = size;
  }
}

abstract class Prefab extends EntityBase {
  final HtmlElement e;
  int id;

  String get img;

  Prefab() : e = DivElement() {
    e
      ..className = 'prefab'
      ..onClick.listen((_) {
        selectedPrefab = this;
      });
  }

  void _updateImage() {
    e.style.backgroundImage = 'url($img)';
  }

  void fromJson(Map<String, dynamic> json) {
    size = json['size'] ?? 1;
  }
}

class CharacterPrefab extends Prefab {
  Character _character;
  Character get character => _character;
  set character(Character c) {
    _character = c;
    _updateImage();
  }

  @override
  String get img => character.img;
}

class CustomPrefab extends Prefab {
  @override
  String get img => getGameFile('$IMAGE_TYPE_ENTITY$id.png');

  CustomPrefab({int size = 1, @required int id}) {
    _size = size;
    this.id = id;
    _updateImage();
  }
}
