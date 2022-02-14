import 'dart:html';

import 'package:meta/meta.dart';

void listenLazyUpdate(
  InputElement input, {
  @required void Function(String s) onChange,
  @required void Function(String s) onSubmit,
  void Function() onFocus,
}) {
  String startValue;
  String typedValue;

  void update() {
    if (startValue != typedValue) {
      startValue = typedValue;
      onChange(typedValue);
      onSubmit(typedValue);
    }
  }

  void onFoc() {
    startValue = input.value;
    if (onFocus != null) onFocus();
    typedValue = input.value;
  }

  input.onMouseDown.listen((_) {
    // Firefox number inputs can trigger onInput without being focused
    var isFocused = document.activeElement == input;
    if (!isFocused) {
      input.focus();
      onFoc();
    }
  });

  input.onFocus.listen((_) => onFoc());
  input.onInput.listen((_) {
    onChange(typedValue = input.value);
  });
  input.onBlur.listen((_) => update());
  input.onChange.listen((_) => update());
}
