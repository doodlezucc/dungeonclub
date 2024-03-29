import 'dart:html';

import 'package:dungeonclub/iterable_extension.dart';
import 'package:dungeonclub/models/token_bar.dart';

import '../html/color_palette.dart';
import '../html/component.dart';
import '../html/input_extension.dart';
import '../html_helpers.dart';
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
  late ColorPalette palette = ColorPalette(
    queryDom('#barConfigColor'),
    colors: TokenBar.colors,
  );

  SelectionTokenBar? _attachedBar;
  late Map<Movable, TokenBar> _affectedBars;

  TokenBarConfigPanel() : super('#barConfiguration') {
    palette.onSelect.listen(_onSelectColor);

    for (var i = 0; i < _visibilityRoot.children.length; i++) {
      final button = _visibilityRoot.children[i];

      button.onClick.listen((event) => _onClickSegmentedButton(i));
    }

    _labelInput.listenLazyUpdate(
      onChange: (text) {
        _modifySimilarTokenBars((token, bar) {
          bar.label = _labelInput.value!;
          token.getTokenBarComponent(bar).applyData();
        });

        _attachedBar!.applyDataToInputs();
      },
      onSubmit: (_) => _attachedBar!.submitData(),
    );

    _removeButton.onClick.listen((_) {
      _removeButton.classes.remove('hovered');
      _modifySimilarTokenBars((token, bar) {
        token.bars.remove(bar);
        token.onRemoveTokenBar(bar);
      });

      _attachedBar!
        ..token.board.selectedBars.remove(_attachedBar!)
        ..submitData();
    });
  }

  void _onSelectColor(String color) {
    _modifySimilarTokenBars((token, bar) {
      bar.color = color;
      token.getTokenBarComponent(bar).applyData();
    });
    _attachedBar!.submitData();
  }

  void _modifySimilarTokenBars(
      void Function(Movable token, TokenBar bar) modify) {
    modify(_attachedBar!.token, _attachedBar!.data);

    for (var movable in _affectedBars.keys) {
      final bar = _affectedBars[movable]!;
      modify(movable, bar);
    }
  }

  Map<Movable, TokenBar> _findAffectedBars() {
    final tokens = _attachedBar!.token.board.selected;
    final activeLabel = _attachedBar!.data.label;

    final affected = <Movable, TokenBar>{};
    for (var movable in tokens.where((m) => m != _attachedBar!.token)) {
      final similarBar = movable.bars.find((bar) => bar.label == activeLabel);
      if (similarBar != null) {
        affected[movable] = similarBar;
      }
    }

    return affected;
  }

  void attachTo(SelectionTokenBar barComponent) {
    _setDomVisible(false);
    barComponent.htmlRoot.append(htmlRoot);
    _applyBarData(barComponent);

    _attachedBar = barComponent;
    _affectedBars = _findAffectedBars();
    _setDomVisible(true);

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
    palette.activeColor = barComponent.data.color;
  }

  void _setDomVisible(bool visible) {
    _attachedBar?.styleHighlight = visible;
    htmlRoot.classes.toggle('show', visible);
  }

  void _onClickSegmentedButton(int index) {
    final visibility = _visibilityButtonOrder[index];
    _applyVisiblity(visibility);

    _modifySimilarTokenBars((token, bar) {
      bar.visibility = visibility;
      token.getTokenBarComponent(bar).applyData();
    });

    _attachedBar!.applyVisibilityIcon();
    _attachedBar!.submitData();
  }

  void _applyVisiblity(TokenBarVisibility visibility) {
    final buttonIndex = _visibilityButtonOrder.indexOf(visibility);
    _visibilityRoot.querySelectorAll('.active').classes.remove('active');

    _visibilityRoot.children[buttonIndex].classes.add('active');
  }
}
