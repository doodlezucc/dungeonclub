import 'dart:async';
import 'dart:html';

import 'package:dungeonclub/models/token_bar.dart';

import '../html/instance_component.dart';
import 'movable.dart';

class TokenBarComponent extends InstanceComponent {
  final Movable token;
  final TokenBar data;
  late SpanElement _labelElement;
  late SpanElement _valueElement;

  set highlight(bool value) {
    htmlRoot.classes.toggle('active', value);
  }

  TokenBarComponent(this.token, this.data) : super(LIElement()) {
    htmlRoot
      ..className = 'token-bar'
      ..append(DivElement()..className = 'bar-fill')
      ..append(_labelElement = SpanElement()..className = 'token-bar-label')
      ..append(_valueElement = SpanElement()..className = 'token-bar-value');

    applyData();
  }

  @override
  List<StreamSubscription> initializeListeners() => [
        token.board.selected.onSetActive
            .listen((event) => _onActiveMovableChange(event.active)),
      ];

  void _onActiveMovableChange(Movable? activeToken) {
    final isDM = token.board.session.isDM;
    final isTokenSelected = token.board.selected.contains(token);

    if (!isDM || activeToken == null || !isTokenSelected) {
      highlight = false;
      return;
    }

    highlight = activeToken.bars.any(
      (activeBar) => activeBar.label == data.label,
    );
  }

  void applyData() {
    double progress;
    String valueText;

    if (data.maxValue == 0) {
      progress = 1;
      valueText = '${data.value}';
    } else {
      progress = data.value / data.maxValue;
      valueText = '${data.value} / ${data.maxValue}';
    }

    htmlRoot.style.setProperty('--progress', '$progress');
    htmlRoot.style.setProperty('--hue', '${data.hue}');
    _labelElement.text = data.label;
    _valueElement.text = valueText;
  }
}
