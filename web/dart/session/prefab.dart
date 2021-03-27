import 'dart:html';
import 'dart:math';

import 'package:dnd_interactive/actions.dart';
import 'package:meta/meta.dart';

import '../communication.dart';
import 'character.dart';
import 'movable.dart';
import 'prefab_palette.dart';

abstract class EntityBase {
  int _size;
  int get size => _size;
  set size(int size) {
    _size = min(max(size, 0), 25);
  }
}

abstract class Prefab extends EntityBase {
  final HtmlElement e;
  final List<Movable> movables = [];

  String get id;
  String get img;

  @override
  set size(int size) {
    super.size = max(size, 1);
    movables.forEach((m) => m.onPrefabUpdate());
  }

  Prefab() : e = DivElement() {
    e
      ..className = 'prefab'
      ..onClick.listen((_) {
        if (selectedPrefab == this) {
          selectedPrefab = null;
        } else {
          selectedPrefab = this;
        }
      });
  }

  String updateImage() {
    var src = img;
    e.style.backgroundImage = 'url($src)';
    return src;
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
    updateImage();
  }

  @override
  String get id => 'c${_character.id}';

  @override
  String get img => character.img;
}

class CustomPrefab extends Prefab {
  int _id;
  String name;

  @override
  String get id => '$_id';

  @override
  String get img => getGameFile('$IMAGE_TYPE_ENTITY$id.png');

  CustomPrefab({int size = 1, this.name = 'Enemy', @required int id}) {
    _size = size;
    _id = id;
    updateImage();
  }
}
