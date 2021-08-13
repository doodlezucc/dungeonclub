import 'dart:html';
import 'dart:math' as math;

import 'package:dnd_interactive/point_json.dart';
import 'package:meta/meta.dart';

import '../font_awesome.dart';
import 'board.dart';
import 'condition.dart';
import 'prefab.dart';

class Movable extends EntityBase {
  final e = DivElement();
  final _aura = DivElement();
  final Board board;
  final Prefab prefab;
  final int id;
  final Set<int> _conds = {};
  Iterable<int> get conds => _conds;

  String get name => prefab.name;

  bool get accessible {
    if (board.session.isDM) return true;

    var charId = board.session.charId;
    if (prefab is CharacterPrefab) {
      return (prefab as CharacterPrefab).character.id == charId;
    }
    if (prefab is CustomPrefab) {
      return (prefab as CustomPrefab).accessIds.contains(charId);
    }
    return false;
  }

  double _auraRadius;
  double get auraRadius => _auraRadius;
  set auraRadius(double auraRadius) {
    _auraRadius = auraRadius;
    _aura.style.display = auraRadius == 0 ? 'none' : '';
    _aura.style.setProperty('--aura', '$auraRadius');
  }

  Point _position;
  Point get position => _position;
  set position(Point position) {
    _position = position;
    e.style
      ..setProperty('--x', '${position.x}')
      ..setProperty('--y', '${position.y}');
  }

  @override
  set size(int size) {
    super.size = size;
    e.style.setProperty('--size', '$displaySize');
  }

  int get displaySize => size != 0 ? size : prefab.size;

  Movable._({
    @required this.board,
    @required this.prefab,
    @required this.id,
    @required Point pos,
    @required Iterable<int> conds,
  }) {
    e
      ..className = 'movable'
      ..append(_aura..className = 'aura')
      ..append(DivElement()..className = 'ring')
      ..append(DivElement()..className = 'img')
      ..append(DivElement()..className = 'conds');

    prefab.movables.add(this);
    onImageChange(prefab.img(cacheBreak: false));
    position = pos ?? Point(0, 0);
    applyConditions(conds);

    super.size = 0;
    onPrefabUpdate();
  }

  static Movable create({
    @required Board board,
    @required Prefab prefab,
    @required int id,
    @required Point pos,
    @required Iterable<int> conds,
  }) {
    if (prefab is EmptyPrefab) {
      return EmptyMovable._(
          board: board, prefab: prefab, id: id, pos: pos, conds: conds);
    }
    return Movable._(
        board: board, prefab: prefab, id: id, pos: pos, conds: conds);
  }

  void onPrefabUpdate() {
    e.style.setProperty('--size', '$displaySize');
    e.classes.toggle('accessible', accessible);
  }

  void onMove(Point delta) async {
    e.classes.add('animate-move');
    position += delta;
    await Future.delayed(Duration(milliseconds: 300));
    e.classes.remove('animate-move');
  }

  void onImageChange(String img) {
    e.querySelector('.img').style.backgroundImage = 'url($img)';
  }

  void roundToGrid() {
    position = Point(position.x.round(), position.y.round());
  }

  void snapToGrid(Point pos) {
    var p = pos ?? position;

    num modify(num v) {
      return (v / board.grid.cellSize).round();
    }

    position = Point(modify(p.x), modify(p.y));
  }

  bool toggleCondition(int id) {
    var didAdd = false;
    if (!_conds.remove(id)) {
      _conds.add(id);
      didAdd = true;
    }
    _applyConds();
    return didAdd;
  }

  void _applyConds() {
    var container = e.querySelector('.conds');
    for (var child in List<Element>.from(container.children)) {
      child.remove();
    }

    for (var id in _conds) {
      var cond = Condition.items[id];
      container
          .append(icon(cond.icon)..append(SpanElement()..text = cond.name));
    }
  }

  void applyConditions(Iterable<int> conds) {
    _conds.clear();
    _conds.addAll(conds);
    _applyConds();
  }

  void onRemove() async {
    prefab.movables.remove(this);

    e.classes.add('animate-remove');
    await Future.delayed(Duration(milliseconds: 500));
    e.remove();
  }

  Map<String, dynamic> toCloneJson() => {
        'prefab': prefab.id,
        'conds': _conds.toList(),
        'aura': auraRadius,
        ...writePoint(position),
        ...super.toJson(),
      };

  @override
  Map<String, dynamic> toJson() => {
        'movable': id,
        'conds': _conds.toList(),
        'aura': auraRadius,
        ...super.toJson(),
      };

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    auraRadius = json['aura'] ?? 0;
    applyConditions(List<int>.from(json['conds'] ?? []));
  }
}

class EmptyMovable extends Movable {
  SpanElement _labelSpan;

  String _label = '';
  String get label => _label;
  set label(String label) {
    _label = label;
    _labelSpan.text = label;

    var lines = label.split(' ');

    var length = lines.fold(0, (len, line) => math.max<int>(len, line.length));
    _labelSpan.style.setProperty('--length', '${length + 1}');
  }

  @override
  String get name => label;

  EmptyMovable._({
    @required Board board,
    @required EmptyPrefab prefab,
    @required int id,
    @required Point pos,
    @required Iterable<int> conds,
  }) : super._(board: board, prefab: prefab, id: id, pos: pos, conds: conds) {
    e
      ..classes.add('empty')
      ..append(_labelSpan = SpanElement());
  }

  @override
  void onImageChange(String img) {}

  @override
  Map<String, dynamic> toCloneJson() => {
        ...super.toCloneJson(),
        'label': label,
      };

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'label': label,
      };

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    label = json['label'] ?? '';
  }
}
