import 'dart:async';
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

int _blockStack = 0;
StreamSubscription _pageExitSub = window.onBeforeUnload.listen((ev) {
  if (_blockStack > 0) {
    ev.preventDefault();
    (ev as BeforeUnloadEvent).returnValue = '';
  }
});

set blockPageExit(bool block) {
  _pageExitSub.resume(); // Initialize unload handler
  if (block) {
    _blockStack++;
  } else if (_blockStack > 0) {
    _blockStack--;
  }
}
