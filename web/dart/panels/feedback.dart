import 'dart:async';
import 'dart:html';

import 'package:dungeonclub/actions.dart';

import '../../main.dart';
import '../communication.dart';
import '../html_helpers.dart';
import 'panel_overlay.dart';

final HtmlElement _panel = queryDom('#feedbackPanel');
final SelectElement _select = _panel.queryDom('select');
final TextAreaElement _content = _panel.queryDom('textarea')
  ..onInput.listen((_) => _updateSendButton());
final ButtonElement _cancelButton = _panel.queryDom('button.close');
final ButtonElement _sendButton = _panel.queryDom('#sendFeedback');

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
  _sendButton.disabled = _content.value!.length < 20;
}
