import 'dart:async';
import 'dart:html';

import '../../main.dart';
import '../html_helpers.dart';
import 'panel_overlay.dart';

final HtmlElement _panel = queryDom('#joinPanel');
final InputElement _sessionNameInput = _panel.queryDom('#sessionName')
  ..onInput.listen((_) => _updateJoinButton());

final ButtonElement _cancelButton = _panel.queryDom('button.close');
final ButtonElement _joinButton = _panel.queryDom('button#join');
final HtmlElement _error = _panel.queryDom('#joinError');

Future<void> display(String gameId) async {
  overlayVisible = true;
  _joinButton.disabled = true;
  _error.text = '';

  _sessionNameInput
    ..value = window.localStorage['name'] ?? ''
    ..select();

  _updateJoinButton();

  var closer = Completer();
  var subs = [
    _joinButton.onClick.listen((_) async {
      _cancelButton.disabled = true;
      if (await _tryJoin(gameId)) closer.complete();
      _cancelButton.disabled = false;
    }),
    _sessionNameInput.onKeyDown.listen((ev) async {
      if (ev.keyCode == 13 && !_joinButton.disabled) {
        _cancelButton.disabled = true;
        if (await _tryJoin(gameId)) closer.complete();
        _cancelButton.disabled = false;
      }
    }),
    _cancelButton.onClick.listen((event) => closer.complete()),
  ];

  _panel.classes.add('show');

  await closer.future;
  _panel.classes.remove('show');
  subs.forEach((s) => s.cancel());
  overlayVisible = false;
}

Future<bool> _tryJoin(String gameId) async {
  window.localStorage['name'] = _sessionNameInput.value;
  _joinButton.disabled = true;
  _error
    ..className = ''
    ..text = 'Access requested...';

  var err = await user.joinSession(gameId, _sessionNameInput.value);

  if (err == null) return true;

  _joinButton.disabled = false;
  _error
    ..className = 'bad'
    ..text = err.message;
  return false;
}

void _updateJoinButton() {
  _joinButton.disabled = _sessionNameInput.value.isEmpty;
}
