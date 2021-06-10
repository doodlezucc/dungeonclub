import 'dart:html';

HtmlElement _overlay = querySelector('#overlay');

int _stack = 0;

set overlayVisible(bool visible) {
  if (visible) {
    if (_stack == 0) {
      _overlay.classes.add('block');
    }

    _stack++;
  } else {
    _stack--;

    if (_stack == 0) {
      _overlay.classes.remove('block');
    }
  }
}
