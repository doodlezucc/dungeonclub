import 'dart:html';
import 'dart:math';

import 'package:dungeonclub/actions.dart';
import 'package:dungeonclub/models/entity_base.dart';
import 'package:meta/meta.dart';

import '../../main.dart';
import '../font_awesome.dart';
import '../resource.dart';
import 'character.dart';
import 'movable.dart';
import 'prefab_palette.dart';

abstract class ClampedEntityBase extends EntityBase {
  int get minSize;

  @override
  int get jsonFallbackSize => minSize;

  @override
  set size(int size) {
    super.size = min(max(size, minSize), 25);
  }
}

abstract class Prefab extends ClampedEntityBase {
  final HtmlElement e;
  final SpanElement _nameSpan;
  final Resource image;

  Iterable<Movable> get movables =>
      user.session.board.movables.where((movable) => movable.prefab == this);

  String get id;
  String get name;

  @override
  int get minSize => 1;

  @override
  set size(int size) {
    super.size = size;
    movables.forEach((m) => m.onPrefabUpdate());
  }

  Prefab(this.image)
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

  void applyImage() {
    final src = image.url;
    if (user.session.isDM) {
      e.style.backgroundImage = 'url($src)';
    }
  }

  void applyName() {
    _nameSpan.text = name;
  }
}

class EmptyPrefab extends Prefab {
  @override
  String get id => 'e';

  @override
  String get name => 'Labeled Token';

  String get iconId => 'pen';

  EmptyPrefab() : super(null) {
    this.e.append(icon(iconId));
    applyName();
  }
}

mixin HasInitiativeMod on Prefab {
  int initiativeMod = 0;

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    initiativeMod = json['mod'] ?? 0;
  }
}

mixin ChangeableName on Prefab {
  String _name;

  @override
  String get name => _name;
  set name(String name) {
    _name = name;
    applyName();
  }

  @override
  void applyName() {
    super.applyName();

    user.session.board.onPrefabNameChange(this);
    for (var m in movables) {
      user.session.board.initiativeTracker.onNameUpdate(m);
      m.updateTooltip();
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'name': name,
      };

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    if (json['name'] != null) name = json['name'];
  }
}

class CharacterPrefab extends Prefab with HasInitiativeMod, ChangeableName {
  Character _character;
  Character get character => _character;
  set character(Character c) {
    _character = c;
    applyImage();
    applyName();
  }

  @override
  String get id => 'c${character.id}';

  @override
  set name(String name) {
    super.name = name;
    character.applyNameToOnlineIndicator();
  }

  CharacterPrefab(int id, String name)
      : super(GameResource('$IMAGE_TYPE_PC$id')) {
    _name = name;
  }
}

class CustomPrefab extends Prefab with HasInitiativeMod, ChangeableName {
  final int _id;
  final Set<int> accessIds = {};

  @override
  String get id => '$_id';
  int get idNum => _id;

  CustomPrefab({@required int id})
      : _id = id,
        super(GameResource('$IMAGE_TYPE_ENTITY$id'));

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'access': accessIds.toList(),
      };

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    accessIds.clear();
    accessIds.addAll(Set.from(json['access']));

    applyImage();
  }
}
