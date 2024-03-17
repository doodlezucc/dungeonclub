import 'dart:html';

import '../html/component.dart';
import '../html/popup_panel.dart';
import '../html_helpers.dart';
import '../panels/upload.dart';
import 'board.dart';
import 'condition.dart';
import 'movable.dart';

class SelectionConditions extends Component {
  final Map<int, ConditionTile> _activeConditionTiles = {};
  final Map<int, ConditionTile> _popupConditions = {};

  final Board board;
  final conditionsPopup = PopupPanel('#conds');

  Element get _activeConditionsContainer => queryDom('#activeConds');

  SelectionConditions(this.board) : super('#selectionConditions') {
    _initializeAddButton();
    _initializeClearButton();
    _createPopupContent();
  }

  void _initializeAddButton() {
    final addButton = queryDom('#addCondition');
    addButton.onLMB.listen((_) {
      conditionsPopup.visible = true;
    });
  }

  void _initializeClearButton() {
    queryDom('#clearConditions').onLMB.listen((_) {
      // Only clear conditions if any are active
      if (board.activeMovable!.conds.isNotEmpty) {
        board.selected.forEach((m) => m.applyConditions([]));
        _disposeConditionTiles();

        board.sendSelectedMovablesUpdate();
      }
    });
  }

  void _createPopupContent() {
    final categories = Condition.categories;
    for (var category in categories) {
      final row = _createGridRow(category);
      conditionsPopup.htmlRoot.append(row);
    }
  }

  Element _createGridRow(ConditionCategory category) {
    final row = DivElement()..className = 'toolbox';
    final div = DivElement()
      ..append(ParagraphElement()..text = category.name)
      ..append(row);

    for (var conditionId in category.conditions.keys) {
      final tile = ConditionTile(conditionId, onClick: _onClickPopupCondition);

      row.append(tile.htmlRoot);
      _popupConditions[conditionId] = tile;
    }

    return div;
  }

  void _onClickPopupCondition(ConditionTile tile) {
    final movable = board.activeMovable!;

    final doEnable = !movable.conds.contains(tile.conditionId);
    _setConditionState(tile.conditionId, doEnable);

    board.selected.forEach(
      (m) => m.toggleCondition(tile.conditionId, doEnable),
    );
    board.sendSelectedMovablesUpdate();
  }

  void onActiveTokenChange(Movable token) {
    _disposeConditionTiles();

    for (var conditionId in token.conds) {
      _setConditionState(conditionId, true);
    }
  }

  void _disposeConditionTiles() {
    final activeIds = _activeConditionTiles.keys.toList();

    for (var conditionId in activeIds) {
      _setConditionState(conditionId, false);
    }

    _activeConditionTiles.clear();
  }

  void _setConditionState(int id, bool enable) {
    if (enable) {
      _addActiveCondition(id);
    } else {
      final tile = _activeConditionTiles[id]!;
      tile.htmlRoot.remove();
      _activeConditionTiles.remove(id);
    }

    _popupConditions[id]!.highlight = enable;
  }

  void _addActiveCondition(int conditionId) {
    final component = ConditionTile(
      conditionId,
      highlight: true,
      onClick: _onClickActiveCondition,
    );

    _activeConditionsContainer.append(component.htmlRoot);
    _activeConditionTiles[conditionId] = component;
  }

  void _onClickActiveCondition(ConditionTile tile) {
    final doEnable = false;
    board.selected
        .forEach((m) => m.toggleCondition(tile.conditionId, doEnable));
    board.sendSelectedMovablesUpdate();

    _setConditionState(tile.conditionId, doEnable);
  }
}

typedef OnConditionClick = void Function(ConditionTile tile);

class ConditionTile extends Component {
  final int conditionId;
  final Condition condition;
  final OnConditionClick onClick;

  bool _highlight = false;
  bool get highlight => _highlight;
  set highlight(bool value) {
    _highlight = value;
    htmlRoot.classes.toggle('active', value);
  }

  ConditionTile(
    int conditionId, {
    required OnConditionClick onClick,
    bool highlight = false,
  }) : this._initialized(
          conditionId,
          Condition.getConditionById(conditionId),
          onClick,
          highlight,
        );

  ConditionTile._initialized(
    this.conditionId,
    this.condition,
    this.onClick,
    bool highlight,
  ) : super.element(icon(condition.icon)) {
    htmlRoot.append(SpanElement()..text = condition.name);

    htmlRoot.onLMB.listen((_) => onClick(this));
    this.highlight = highlight;
  }
}
