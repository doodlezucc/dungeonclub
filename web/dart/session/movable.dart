import 'dart:html';
import 'dart:math' as math;

import 'package:dungeonclub/point_json.dart';
import 'package:grid/grid.dart';
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

  String _label = '';
  String get label => _label;
  set label(String label) {
    _label = label;
    board.initiativeTracker.onNameUpdate(this);
    updateTooltip();
  }

  String get displayName {
    if (label.isEmpty) return prefab.name;
    return '${prefab.name} ($label)';
  }

  bool get invisible => e.classes.contains('invisible');
  set invisible(bool invisible) => e.classes.toggle('invisible', invisible);

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
    _position = position.snapDeviation();
    applyPosition();
  }

  @override
  set size(int size) {
    super.size = size;
    e.style.setProperty('--size', '$displaySize');
    applyPosition();
  }

  int get displaySize => size != 0 ? size : prefab.size;
  Point<int> get displaySizePoint => Point(displaySize, displaySize);
  Point<double> get topLeft =>
      position.cast<double>() - Point(0.5 * displaySize, 0.5 * displaySize);

  Movable._({
    @required this.board,
    @required this.prefab,
    @required this.id,
    @required Point pos,
    @required Iterable<int> conds,
    bool createTooltip = true,
  }) {
    e
      ..className = 'movable'
      ..append(_aura..className = 'aura')
      ..append(DivElement()..className = 'ring')
      ..append(DivElement()..className = 'img')
      ..append(DivElement()..className = 'conds');

    if (createTooltip) {
      e.append(board.transform.registerInvZoom(
        SpanElement()..className = 'toast',
        scaleByCell: true,
      ));
    }

    prefab.movables.add(this);
    onImageChange(prefab.img(cacheBreak: false));
    applyConditions(conds);

    super.size = 0;
    position = pos ?? Point(0, 0);
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

  void applyPosition() {
    var pos = board.grid.grid.gridToWorldSpace(_position);
    board.updateSnapToGrid();

    e.style
      ..setProperty('--x', '${pos.x}px')
      ..setProperty('--y', '${pos.y}px');
  }

  void setSizeWithGridSpecifics(int newSize) {
    final oldTopLeft = topLeft;
    size = newSize;

    if (board.grid.grid is SquareGrid) {
      position = position.cast<num>() + oldTopLeft - topLeft;
    }
  }

  void updateTooltip() {
    e.querySelector('.toast').text = displayName;
  }

  void onPrefabUpdate() {
    if (size == 0) {
      e.style.setProperty('--size', '$displaySize');
      applyPosition();
    }
    e.classes.toggle('accessible', accessible);
    updateTooltip();
  }

  void onMove(Point delta) async {
    position = position.cast<num>() + delta;
  }

  void onImageChange(String img) {
    e.querySelector('.img').style.backgroundImage = 'url($img)';
  }

  void roundToGrid() {
    position =
        board.grid.grid.gridSnapCentered(position.cast<double>(), displaySize);
  }

  bool toggleCondition(int id, [bool add]) {
    var didAdd = false;
    if (add != null) {
      didAdd = add ? _conds.add(id) : _conds.remove(id);
    } else if (!_conds.remove(id)) {
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
    board.movables.remove(this);
    board.initiativeTracker.onRemove(this);

    e.classes.add('animate-remove');
    await Future.delayed(Duration(milliseconds: 500));
    board.transform.unregisterInvZoom(e.querySelector('.toast'));
    e.remove();
  }

  Map<String, dynamic> toCloneJson() => {
        'prefab': prefab.id,
        ..._sharedJson(),
      };

  @override
  Map<String, dynamic> toJson() => {
        'movable': id,
        ..._sharedJson(),
      };

  Map<String, dynamic> _sharedJson() => {
        ...writePoint(position),
        'label': label,
        'conds': _conds.toList(),
        'aura': auraRadius,
        'invisible': invisible,
        ...super.toJson(),
      };

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    position = parsePoint(json);
    label = json['label'] ?? '';
    auraRadius = json['aura'] ?? 0;
    invisible = json['invisible'] ?? false;
    applyConditions(List<int>.from(json['conds'] ?? []));
  }
}

class EmptyMovable extends Movable {
  SpanElement _labelSpan;

  @override
  set label(String label) {
    super.label = label;

    _labelSpan.text = label;
    var lines = label.split(' ');

    var length = lines.fold(0, (len, line) => math.max<int>(len, line.length));
    _labelSpan.style.setProperty('--length', '${length + 1}');
  }

  EmptyMovable._({
    @required Board board,
    @required EmptyPrefab prefab,
    @required int id,
    @required Point pos,
    @required Iterable<int> conds,
  }) : super._(
          board: board,
          prefab: prefab,
          id: id,
          pos: pos,
          conds: conds,
          createTooltip: false,
        ) {
    e
      ..classes.add('empty')
      ..append(_labelSpan = SpanElement());
  }

  @override
  void onImageChange(String img) {}

  @override
  void updateTooltip() {}
}
