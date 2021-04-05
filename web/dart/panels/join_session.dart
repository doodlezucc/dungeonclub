import 'dart:async';
import 'dart:html';

import '../../main.dart';

final HtmlElement _panel = querySelector('#joinPanel');
final InputElement _sessionNameInput = _panel.querySelector('#sessionName')
  ..onInput.listen((_) => _updateJoinButton());

// final ButtonElement _cancelButton = _panel.querySelector('button.close');
final ButtonElement _joinButton = _panel.querySelector('button#join');
final HtmlElement _error = _panel.querySelector('#joinError');

Future<void> display(String gameId) async {
  _joinButton.disabled = true;
  _error.text = '';

  _sessionNameInput
    ..value = ''
    ..focus();

  _updateJoinButton();

  var closer = Completer();
  var subs = [
    _joinButton.onClick.listen((event) async {
      _joinButton.disabled = true;
      _error.text = '';

      var err = await user.joinSession(gameId);

      if (err == null) {
        closer.complete();
      } else {
        _error.text = err.message;
        _joinButton.disabled = false;
      }
    }),
    // _cancelButton.onClick.listen((event) => closer.complete()),
  ];

  _panel.classes.add('show');

  await closer.future;
  _panel.classes.remove('show');
  subs.forEach((s) => s.cancel());
}

void _updateJoinButton() {
  _joinButton.disabled = _sessionNameInput.value.isEmpty;
}
