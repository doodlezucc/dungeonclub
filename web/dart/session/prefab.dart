import 'dart:html';
import 'dart:math';

import 'package:dungeonclub/actions.dart';
import 'package:dungeonclub/models/entity_base.dart';
import 'package:meta/meta.dart';

import '../../main.dart';
import '../communication.dart';
import '../font_awesome.dart';
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

  Iterable<Movable> get movables =>
      user.session.board.movables.where((movable) => movable.prefab == this);

  String get id;
  String img({bool cacheBreak = true});
  String get name;

  @override
  int get minSize => 1;

  @override
  set size(int size) {
    super.size = size;
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

  String applyImage({bool cacheBreak = true}) {
    var src = img(cacheBreak: cacheBreak);
    if (user.session.isDM) {
      e.style.backgroundImage = 'url($src)';
    }
    return src;
  }

  void applyName() {
    _nameSpan.text = name;
  }
}

class EmptyPrefab extends Prefab {
  @override
  String get id => 'e';

  @override
  String img({bool cacheBreak = true}) => '';

  @override
  String get name => 'Labeled Token';

  String get iconId => 'pen';

  EmptyPrefab() {
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

class CharacterPrefab extends Prefab with HasInitiativeMod {
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
  String get name => character.name;

  @override
  String img({bool cacheBreak = true}) => character.img;
}

class CustomPrefab extends Prefab with HasInitiativeMod {
  final int _id;
  String _name;
  String _bufferedImg;
  final Set<int> accessIds = {};

  @override
  String get id => '$_id';
  int get idNum => _id;

  @override
  String get name => _name;
  set name(String name) {
    _name = name;
    applyName();

    user.session.board.onPrefabNameChange(this);
    for (var m in movables) {
      user.session.board.initiativeTracker.onNameUpdate(m);
      m.updateTooltip();
    }
  }

  CustomPrefab({@required int id}) : _id = id;

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

    applyImage(cacheBreak: false);
  }

  @override
  String img({bool cacheBreak = true}) {
    if (cacheBreak || _bufferedImg == null) {
      _bufferedImg =
          getGameFile('$IMAGE_TYPE_ENTITY$id', cacheBreak: cacheBreak);
    }
    return _bufferedImg;
  }
}
