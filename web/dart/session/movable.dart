import 'dart:async';
import 'dart:html';
import 'dart:math' as math;

import 'package:dungeonclub/models/entity_base.dart';
import 'package:dungeonclub/models/token.dart';
import 'package:dungeonclub/models/token_bar.dart';
import 'package:dungeonclub/point_json.dart';
import 'package:grid_space/grid_space.dart';

import '../html/instance_component.dart';
import '../html/instance_list.dart';
import '../html_helpers.dart';
import 'board.dart';
import 'condition.dart';
import 'prefab.dart';
import 'token_bar_component.dart';

class Movable extends InstanceComponent
    with EntityBase, ClampedEntityBase, TokenModel {
  @override
  final int id;
  final Board board;
  final Prefab prefab;

  @override
  String get prefabId => prefab.id;

  final _aura = DivElement();
  final _barsRoot = UListElement();
  late final barInstances = InstanceList<TokenBarComponent>(_barsRoot);

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

  @override
  int get minSize => 0;

  @override
  set label(String label) {
    super.label = label;
    board.initiativeTracker.onNameUpdate(this);
    updateTooltip();
  }

  String get displayName {
    if (label.isEmpty) return prefab.name;
    return '${prefab.name} ($label)';
  }

  @override
  set angle(double angle) {
    super.angle = angle;
    htmlRoot.style.setProperty('--angle', '$angle');
  }

  @override
  set invisible(bool invisible) {
    super.invisible = invisible;
    htmlRoot.classes.toggle('invisible', invisible);
  }

  set styleActive(bool value) {
    htmlRoot.classes.toggle('active', value);
  }

  bool get styleSelected => htmlRoot.classes.contains('selected');
  set styleSelected(bool value) {
    htmlRoot.classes.toggle('selected', value);
  }

  set styleHovered(bool value) {
    htmlRoot.classes.toggle('hovered', value);
  }

  set stylePreventTransition(bool value) {
    htmlRoot.classes.toggle('no-animate-move', value);
  }

  @override
  set auraRadius(double auraRadius) {
    super.auraRadius = auraRadius;
    _aura.style.display = auraRadius == 0 ? 'none' : '';
    _aura.style.setProperty('--aura', '$auraRadius');
  }

  @override
  set position(Point<double> position) {
    super.position = position.snapDeviationAny();
    applyPosition();
  }

  @override
  set size(int size) {
    super.size = size;
    htmlRoot.style.setProperty('--size', '$displaySize');
    applyPosition();
  }

  int get displaySize => size != 0 ? size : prefab.size;
  Point<int> get displaySizePoint => Point(displaySize, displaySize);
  Point<double> get topLeft =>
      position - Point(0.5 * displaySize, 0.5 * displaySize);

  Point<double> get positionScreenSpace =>
      board.grid.grid.gridToWorldSpace(position);

  Movable._({
    required this.board,
    required this.prefab,
    required this.id,
    required Point<double>? pos,
    required Iterable<int>? conds,
    bool createTooltip = true,
  }) : super(DivElement()) {
    htmlRoot
      ..className = 'movable'
      ..append(_aura..className = 'aura')
      ..append(DivElement()..className = 'ring')
      ..append(DivElement()..className = 'img rotating')
      ..append(DivElement()..className = 'conds')
      ..append(_barsRoot..className = 'bars');

    if (createTooltip) {
      htmlRoot.append(board.transform.registerInvZoom(
        SpanElement()..className = 'toast',
        scaleByCell: true,
      ));
    }

    applyImage();
    super.size = 0;

    if (pos != null) {
      position = pos;
      onPrefabUpdate();
    }
    if (conds != null) applyConditions(conds);

    _createBarComponents();
    angle = 0;
  }

  static Movable create({
    required Board board,
    required Prefab prefab,
    required int id,
    Iterable<int>? conds,
    Point<double>? pos,
  }) {
    if (prefab is EmptyPrefab) {
      return EmptyMovable._(
          board: board, prefab: prefab, id: id, pos: pos, conds: conds);
    }
    return Movable._(
        board: board, prefab: prefab, id: id, pos: pos, conds: conds);
  }

  @override
  List<StreamSubscription> initializeListeners() => [
        board.selected
            .observe(this)
            .listen((selected) => this.styleSelected = selected)
      ];

  TokenBarComponent getTokenBarComponent(TokenBar data) {
    return barInstances.firstWhere((bar) => bar.data == data);
  }

  void onRemoveTokenBar(TokenBar data) {
    final component = getTokenBarComponent(data);
    barInstances.remove(component);
  }

  TokenBarComponent createTokenBarComponent(TokenBar bar) {
    final component = TokenBarComponent(this, bar);
    barInstances.add(component);
    return component;
  }

  bool _doDisplayTokenBar(TokenBar bar) {
    switch (bar.visibility) {
      case TokenBarVisibility.VISIBLE_TO_ALL:
        return true;
      case TokenBarVisibility.VISIBLE_TO_OWNERS:
        return accessible;
      case TokenBarVisibility.HIDDEN:
        return board.session.isDM;
    }
  }

  void _createBarComponents() {
    barInstances.clear();

    for (final bar in bars) {
      if (_doDisplayTokenBar(bar)) {
        createTokenBarComponent(bar);
      }
    }
  }

  void applyPosition() {
    final pos = positionScreenSpace;
    board.updateSnapToGrid();

    htmlRoot.style
      ..setProperty('--x', '${pos.x}px')
      ..setProperty('--y', '${pos.y}px');
  }

  void setSizeWithGridSpecifics(int newSize) {
    final oldTopLeft = topLeft;
    size = newSize;

    if (board.grid.grid is SquareGrid) {
      position += oldTopLeft - topLeft;
    }
  }

  void updateTooltip() {
    htmlRoot.queryDom('.toast').text = displayName;
  }

  void onPrefabUpdate() {
    if (size == 0) {
      htmlRoot.style.setProperty('--size', '$displaySize');
      applyPosition();
    }
    htmlRoot.classes.toggle('accessible', accessible);
    updateTooltip();
  }

  void applyImage() {
    final img = prefab.image!.url;
    htmlRoot.queryDom('.img').style.backgroundImage = 'url($img)';
  }

  void roundToGrid() {
    position =
        board.grid.grid.gridSnapCentered(position, displaySize).cast<double>();
  }

  bool toggleCondition(int id, [bool? add]) {
    var didAdd = false;
    if (add != null) {
      didAdd = add ? conds.add(id) : conds.remove(id);
    } else if (!conds.remove(id)) {
      conds.add(id);
      didAdd = true;
    }
    _applyConds();
    return didAdd;
  }

  void _applyConds() {
    var container = htmlRoot.queryDom('.conds');
    for (var child in List<Element>.from(container.children)) {
      child.remove();
    }

    for (var id in conds) {
      var cond = Condition.items[id]!;
      container
          .append(icon(cond.icon)..append(SpanElement()..text = cond.name));
    }
  }

  void applyConditions(Iterable<int> conds) {
    this.conds.clear();
    this.conds.addAll(conds);
    _applyConds();
  }

  @override
  void dispose(InstanceList list) async {
    board.initiativeTracker.onRemove(this);

    htmlRoot.classes.add('animate-remove');
    await Future.delayed(Duration(milliseconds: 500));

    final toast = htmlRoot.querySelector('.toast');
    if (toast != null) {
      board.transform.unregisterInvZoom(toast);
    }

    super.dispose(list);
  }

  Map<String, dynamic> toCloneJson() => {
        'prefab': prefab.id,
        ...toJsonExcludeID(),
      };

  @override
  Map<String, dynamic> toJson() => {
        'movable': id,
        ...toJsonExcludeID(),
      };

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    _createBarComponents();
    applyConditions(List<int>.from(json['conds'] ?? []));
    onPrefabUpdate();
  }

  void ping() {
    this.styleSelected = true;
    Future.delayed(const Duration(seconds: 10), () {
      this.styleSelected = false;
    });
  }

  void goTo() {
    this.styleSelected = true;
    board.animateTransformToToken(this);
    Future.delayed(const Duration(seconds: 10), () {
      this.styleSelected = false;
    });
  }
}

class EmptyMovable extends Movable {
  late SpanElement _labelSpan;

  @override
  set label(String label) {
    super.label = label;

    _labelSpan.text = label;
    var lines = label.split(' ');

    var length = lines.fold<int>(0, (len, line) => math.max(len, line.length));
    _labelSpan.style.setProperty('--length', '${length + 1}');
  }

  @override
  String get displayName {
    return label;
  }

  EmptyMovable._({
    required Board board,
    required EmptyPrefab prefab,
    required int id,
    required Point<double>? pos,
    required Iterable<int>? conds,
  }) : super._(
          board: board,
          prefab: prefab,
          id: id,
          pos: pos,
          conds: conds,
          createTooltip: false,
        ) {
    htmlRoot
      ..classes.add('empty')
      ..append(_labelSpan = SpanElement());
  }

  @override
  void applyImage() {}

  @override
  void updateTooltip() {}
}

class AngleArrow {
  static final HtmlElement container = queryDom('#angleArrow');
  static final HtmlElement angleCurrent = queryDom('#angleCurrent');

  bool _visible = false;
  bool get visible => _visible;
  set visible(bool visible) {
    if (_visible == visible) return;
    _visible = visible;
    container.classes.toggle('show', visible);
  }

  Point<double> _origin = Point(0.0, 0.0);
  Point<double> get origin => _origin;
  set origin(Point<double> origin) {
    _origin = origin;
    container.style.setProperty('--x', '${origin.x}px');
    container.style.setProperty('--y', '${origin.y}px');
  }

  double _angle = 0;
  double get angle => _angle;
  set angle(double angle) {
    _angle = angle.undeviate();
    container.style.setProperty('--angle', '$_angle');
  }

  set sourceAngle(double sourceAngle) {
    angleCurrent.style.setProperty('--angle', '$sourceAngle');
  }

  set length(int length) {
    container.style.setProperty('--size', '$length');
  }

  static double _radToDegrees(double rad) {
    return rad * 180 / math.pi;
  }

  static double _degBetween(Point<double> a, Point<double> b) {
    final vector = a - b;
    final radAngleBetween = math.atan2(vector.x, -vector.y);
    return _radToDegrees(radAngleBetween);
  }

  void align(Board board, Point end, {bool updateSourceAngle = false}) {
    final activeMovable = board.activeMovable!;

    origin = board.grid.grid.gridToWorldSpace(activeMovable.position);
    length = activeMovable.displaySize;

    // Snap angle to closest "step" (square: 45°, hex: 30°)
    final degrees = _degBetween(origin, end.cast<double>());
    final degSnapStep = board.grid.measuringRuleset.snapTokenAngle(degrees);

    // Snap cursor position to closest cell
    final endSnapped = board.grid.grid.worldSnapCentered(end, 1).cast<double>();
    final degSnapCell = _degBetween(origin, endSnapped);

    // Check whether the closest step or the hovered cell center
    // is closest to the actual angle
    if ((degrees - degSnapStep).abs() < (degrees - degSnapCell).abs()) {
      angle = degSnapStep;
    } else {
      angle = degSnapCell;
    }

    if (updateSourceAngle) {
      sourceAngle = angle;
    } else {
      sourceAngle = activeMovable.angle;
    }
  }
}

final angleArrow = AngleArrow();
