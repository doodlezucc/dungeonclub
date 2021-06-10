import 'dart:async';
import 'dart:html';

import '../../main.dart';
import 'panel_overlay.dart';

final HtmlElement _panel = querySelector('#joinPanel');
final InputElement _sessionNameInput = _panel.querySelector('#sessionName')
  ..onInput.listen((_) => _updateJoinButton());

// final ButtonElement _cancelButton = _panel.querySelector('button.close');
final ButtonElement _joinButton = _panel.querySelector('button#join');
final HtmlElement _error = _panel.querySelector('#joinError');

Future<void> display(String gameId) async {
  overlayVisible = true;
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
      _error
        ..className = ''
        ..text = 'Requesting access...';

      var err = await user.joinSession(gameId, _sessionNameInput.value);

      if (err == null) {
        closer.complete();
      } else {
        _joinButton.disabled = false;
        _error
          ..className = 'bad'
          ..text = err.message;
      }
    }),
    // _cancelButton.onClick.listen((event) => closer.complete()),
  ];

  _panel.classes.add('show');

  await closer.future;
  _panel.classes.remove('show');
  subs.forEach((s) => s.cancel());
  overlayVisible = false;
}

void _updateJoinButton() {
  _joinButton.disabled = _sessionNameInput.value.isEmpty;
}
