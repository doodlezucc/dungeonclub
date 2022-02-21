import 'dart:async';
import 'dart:html';

import 'package:dnd_interactive/actions.dart';

import '../../main.dart';
import '../communication.dart';
import 'panel_overlay.dart';

final HtmlElement _panel = querySelector('#feedbackPanel');
final SelectElement _select = _panel.querySelector('select');
final TextAreaElement _content = _panel.querySelector('textarea')
  ..onInput.listen((_) => _updateSendButton());
final ButtonElement _cancelButton = _panel.querySelector('button.close');
final ButtonElement _sendButton = _panel.querySelector('#sendFeedback');

Future<void> display() async {
  overlayVisible = true;

  for (var opt in _select.options) {
    if (opt.value == 'account') opt.disabled = !user.registered;
  }

  _content.select();
  _updateSendButton();

  var closer = Completer();
  var subs = [
    _sendButton.onClick.listen((_) async {
      _cancelButton.disabled = true;
      if (await _trySend()) closer.complete();
      _cancelButton.disabled = false;
    }),
    _cancelButton.onClick.listen((_) => closer.complete()),
  ];

  _panel.classes.add('show');

  await closer.future;
  _panel.classes.remove('show');
  subs.forEach((s) => s.cancel());
  overlayVisible = false;
}

Future<bool> _trySend() async {
  _sendButton.disabled = true;

  var sent = await socket.request(FEEDBACK, {
    'type': _select.value,
    'content': _content.value,
  });

  if (sent == true) {
    _content.value = '';
    return true;
  }

  _sendButton.disabled = false;
  return false;
}

void _updateSendButton() {
  _sendButton.disabled = _content.value.length < 20;
}
