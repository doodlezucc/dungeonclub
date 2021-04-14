import 'dart:html';
import 'dart:math';

import 'package:dnd_interactive/actions.dart';
import 'package:meta/meta.dart';

import '../communication.dart';
import 'character.dart';
import 'movable.dart';
import 'prefab_palette.dart';

abstract class EntityBase {
  int _size = 1;
  int get size => _size;
  set size(int size) {
    _size = min(max(size, 0), 25);
  }

  Map<String, dynamic> toJson() => {
        'size': size,
      };

  void fromJson(Map<String, dynamic> json) {
    size = json['size'] ?? 1;
  }
}

abstract class Prefab extends EntityBase {
  final HtmlElement e;
  final SpanElement _nameSpan;
  final List<Movable> movables = [];

  String get id;
  String img({bool cacheBreak = true});
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

  String updateImage({bool cacheBreak = true}) {
    var src = img(cacheBreak: cacheBreak);
    e.style.backgroundImage = 'url($src)';
    return src;
  }

  void updateName() {
    _nameSpan.text = name;
  }
}

class EmptyPrefab extends Prefab {
  @override
  String get id => 'e';

  @override
  String img({bool cacheBreak = true}) => '';

  @override
  String get name => 'Empty';

  EmptyPrefab() {
    updateName();
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
  String img({bool cacheBreak = true}) => character.img;
}

class CustomPrefab extends Prefab {
  int _id;
  String _name;
  final Set<int> accessIds = {};

  @override
  String get id => '$_id';

  @override
  String get name => _name;
  set name(String name) {
    _name = name;
    updateName();
  }

  CustomPrefab({@required int id}) {
    _id = id;
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'name': name,
        'access': accessIds.toList(),
      };

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    name = json['name'];
    accessIds.clear();
    accessIds.addAll(Set.from(json['access']));

    updateImage(cacheBreak: false);
    updateName();
  }

  @override
  String img({bool cacheBreak = true}) =>
      getGameFile('$IMAGE_TYPE_ENTITY$id.png', cacheBreak: cacheBreak);
}
