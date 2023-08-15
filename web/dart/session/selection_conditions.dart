import 'dart:html';

import '../html/component.dart';
import '../html/popup_panel.dart';
import '../html_helpers.dart';
import '../panels/upload.dart';
import 'board.dart';
import 'condition.dart';
import 'movable.dart';

class SelectionConditions extends Component {
  final List<ConditionTile> _activeConditions = [];
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
    queryDom('#clearConditions').onClick.listen((_) {
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

    for (var e in category.conditions.entries) {
      final id = e.key;
      final cond = e.value;

      final tile = ConditionTile(cond, onClick: (tile) {
        final movable = board.activeMovable!;

        final doEnable = !movable.conds.contains(id);

        board.selected.forEach((m) => m.toggleCondition(id, doEnable));
        tile.htmlRoot.classes.toggle('active', doEnable);
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

    for (var condition in _activeConditions) {
      condition.htmlRoot.remove();
    }

    _activeConditions.clear();

    for (var conditionId in token.conds) {
      _addActiveCondition(conditionId);
    }
  }

  void _addActiveCondition(int id) {
    final condition = Condition.getConditionById(id);
    final component = ConditionTile(
      condition,
      onClick: (_) {
        print('click');
      },
    );

    _activeConditionsContainer.append(component.htmlRoot);
    _activeConditions.add(component);
  }
}

class ConditionTile extends Component {
  final Condition condition;
  final void Function(ConditionTile tile) onClick;

  ConditionTile(this.condition, {required this.onClick})
      : super.element(icon(condition.icon)) {
    htmlRoot.append(SpanElement()..text = condition.name);

    htmlRoot.onLMB.listen((_) => onClick(this));
  }
}
