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
    _labelElement.text = data.label;
    _valueElement.text = valueText;
  }

  bool get doDisplayTokenBar {
    switch (data.visibility) {
      case TokenBarVisibility.VISIBLE_TO_ALL:
        return true;
      case TokenBarVisibility.VISIBLE_TO_OWNERS:
        return token.accessible;
      case TokenBarVisibility.HIDDEN:
        return token.board.session.isDM;
    }
  }
}
