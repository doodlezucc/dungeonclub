import 'dart:html';

import '../html/component.dart';
import '../html/popup_panel.dart';
import '../html_helpers.dart';
import '../panels/upload.dart';
import 'board.dart';
import 'condition.dart';
import 'movable.dart';

class SelectionConditions extends Component {
  final List<ConditionTile> _activeConditionTiles = [];
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
        conditionsPopup.htmlRoot
            .querySelectorAll('.active')
            .classes
            .remove('active');

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
      final tile = ConditionTile(conditionId, onClick: (tile) {
        final movable = board.activeMovable!;

        final doEnable = !movable.conds.contains(conditionId);

        board.selected.forEach((m) => m.toggleCondition(conditionId, doEnable));
        tile.highlight = doEnable;
        board.sendSelectedMovablesUpdate();
      });

      row.append(tile.htmlRoot);
    }

    return div;
  }

  void onActiveTokenChange(Movable token) {
    conditionsPopup.htmlRoot
        .querySelectorAll('.active')
        .classes
        .remove('active');

    for (var c = 0; c < Condition.categories.length; c++) {
      final category = Condition.categories[c];
      final row = conditionsPopup.htmlRoot.children[c].children.last;

      for (var cc = 0; cc < category.conditions.length; cc++) {
        if (token.conds.contains(category.conditions.keys.elementAt(cc))) {
          row.children[cc].classes.add('active');
        }
      }
    }

    for (var condition in _activeConditionTiles) {
      condition.htmlRoot.remove();
    }

    _activeConditionTiles.clear();

    for (var conditionId in token.conds) {
      _addActiveCondition(conditionId);
    }
  }

  void _onClickActiveCondition(ConditionTile tile) {
    final doEnable = false;
    board.selected
        .forEach((m) => m.toggleCondition(tile.conditionId, doEnable));
    board.sendSelectedMovablesUpdate();

    _disposeActiveCondition(tile);
  }

  void _addActiveCondition(int conditionId) {
    final component = ConditionTile(
      conditionId,
      highlight: true,
      onClick: _onClickActiveCondition,
    );

    _activeConditionsContainer.append(component.htmlRoot);
    _activeConditionTiles.add(component);
  }

  void _disposeActiveCondition(ConditionTile tile) {
    tile.htmlRoot.remove();
    _activeConditionTiles.remove(tile);
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
