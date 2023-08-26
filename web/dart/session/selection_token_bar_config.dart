import 'dart:html';

import 'package:dungeonclub/models/token_bar.dart';

import '../html/component.dart';
import '../html_helpers.dart';
import '../lazy_input.dart';
import 'movable.dart';
import 'selection_token_bar.dart';

class TokenBarConfigPanel extends Component {
  static const _visibilityButtonOrder = [
    TokenBarVisibility.VISIBLE_TO_ALL,
    TokenBarVisibility.VISIBLE_TO_OWNERS,
    TokenBarVisibility.HIDDEN,
  ];

  final InputElement _labelInput = queryDom('#barConfigLabel');
  final Element _visibilityRoot = queryDom('#barConfigVisibility');
  final ButtonElement _removeButton = queryDom('#barRemoveButton');

  late SelectionTokenBar _attachedBar;

  TokenBarConfigPanel() : super('#barConfiguration') {
    for (var i = 0; i < _visibilityRoot.children.length; i++) {
      final button = _visibilityRoot.children[i];

      button.onClick.listen((event) => _onClickSegmentedButton(i));
    }

    listenLazyUpdate(
      _labelInput,
      onChange: (text) {
        _modifySimilarTokenBars((token, bar) {
          bar.label = _labelInput.value!;
          token.applyBars();
        });

        _attachedBar.applyDataToInputs();
      },
      onSubmit: (_) => _attachedBar.submitData(),
    );

    _removeButton.onClick.listen((_) {
      _modifySimilarTokenBars((token, bar) {
        token.bars.remove(bar);
        token.applyBars();
      });

      _attachedBar
        ..htmlRoot.remove()
        ..submitData();
    });
  }

  void _modifySimilarTokenBars(
      void Function(Movable token, TokenBar bar) modify) {
    _attachedBar.token.board.modifySelectedTokenBars(_attachedBar.data, modify);
  }

  void attachTo(SelectionTokenBar barComponent) {
    _setDomVisible(false);
    barComponent.htmlRoot.append(htmlRoot);
    _applyBarData(barComponent);

    _setDomVisible(true);
    _attachedBar = barComponent;

    document.onMouseDown
        .firstWhere((element) => !element.path.contains(htmlRoot))
        .then((_) => _setDomVisible(false));

    _labelInput
      ..focus()
      ..select();
  }

  void _applyBarData(SelectionTokenBar barComponent) {
    _labelInput.value = barComponent.data.label;
    _applyVisiblity(barComponent.data.visibility);
  }

  void _setDomVisible(bool visible) {
    htmlRoot.classes.toggle('show', visible);
  }

  void _onClickSegmentedButton(int index) {
    final visibility = _visibilityButtonOrder[index];
    _applyVisiblity(visibility);

    _modifySimilarTokenBars((token, bar) {
      bar.visibility = visibility;
      token.applyBars();
    });

    _attachedBar.applyVisibilityIcon();
    _attachedBar.submitData();
  }

  void _applyVisiblity(TokenBarVisibility visibility) {
    final buttonIndex = _visibilityButtonOrder.indexOf(visibility);
    _visibilityRoot.querySelectorAll('.active').classes.remove('active');

    _visibilityRoot.children[buttonIndex].classes.add('active');
  }
}
