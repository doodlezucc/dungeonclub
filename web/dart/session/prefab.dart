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
  final SpanElement _nameSpan;
  final List<Movable> movables = [];

  String get id;
  String get img;
  String get name;

  @override
  set size(int size) {
    super.size = max(size, 1);
    movables.forEach((m) => m.onPrefabUpdate());
  }

  Prefab()
      : e = DivElement(),
        _nameSpan = SpanElement() {
    e
      ..className = 'prefab'
      ..onClick.listen((_) {
        if (selectedPrefab == this) {
          selectedPrefab = null;
        } else {
          selectedPrefab = this;
        }
      })
      ..append(_nameSpan);
  }

  String updateImage() {
    var src = img;
    e.style.backgroundImage = 'url($src)';
    return src;
  }

  void updateName() {
    _nameSpan.text = name;
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
    updateName();
  }

  @override
  String get id => 'c${character.id}';

  @override
  String get name => character.name;

  @override
  String get img => character.img;
}

class CustomPrefab extends Prefab {
  int _id;
  String _name;

  @override
  String get id => '$_id';

  @override
  String get name => _name;
  set name(String name) {
    _name = name;
    updateName();
  }

  @override
  String get img => getGameFile('$IMAGE_TYPE_ENTITY$id.png');

  CustomPrefab({int size, String name, @required int id}) {
    _size = size;
    _id = id;
    _name = name;

    updateImage();
    updateName();
  }

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    name = json['name'];
  }
}
