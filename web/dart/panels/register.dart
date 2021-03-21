import 'dart:async';
import 'dart:html';

import 'package:dnd_interactive/actions.dart';

import '../communication.dart';

final HtmlElement _panel = querySelector('#registerPanel');

final HtmlElement _sectionRegister = _panel.querySelector('#register');
final HtmlElement _sectionActivate = _panel.querySelector('#activate');

final InputElement _emailInput = _panel.querySelector('#regEmail')
  ..onInput.listen((event) => _updateCreateButton());

final InputElement _passwordInput = _panel.querySelector('#regPassword')
  ..onInput.listen((event) => _updateCreateButton());

final InputElement _confirmInput = _panel.querySelector('#regConfirm')
  ..onInput.listen((event) => _updateCreateButton());

final InputElement _codeInput = _panel.querySelector('#regCode');
final SpanElement _emailReader = _panel.querySelector('#regActEmail');

final ButtonElement _registerButton = _panel.querySelector('#regSend');
final ButtonElement _activateButton = _panel.querySelector('#regActivate');

final ButtonElement _cancelButton = _panel.querySelector('button.close');
final ButtonElement _loginButton = querySelector('button#login');

const pwLengthMin = 7;

Future<void> display() async {
  _loginButton.classes.add('disabled');
  _emailInput.value = '';
  _passwordInput.value = '';
  _confirmInput.value = '';
  _updateCreateButton();

  var closer = Completer();
  var subs = [
    _registerButton.onClick.listen((event) async {
      _registerButton.disabled = true;

      var moveOn = await socket.request(ACCOUNT_REGISTER, {
        'email': _emailInput.value,
        'password': _passwordInput.value,
      });

      if (moveOn) {
        _emailReader.text = _emailInput.value;
        _setSection(_sectionActivate);
        _codeInput
          ..value = ''
          ..focus();
      } else {
        _registerButton.disabled = false;
      }
    }),
    _activateButton.onClick.listen((event) async {
      var account = await socket.request(ACCOUNT_ACTIVATE, {
        'code': _codeInput.value,
      });
      if (account == false) return print("Sike! That's the wrong numba!");

      closer.complete();
    }),
    _cancelButton.onClick.listen((event) => closer.complete()),
  ];

  _setSection(_sectionRegister);

  _panel.classes.add('show');

  await closer.future;
  _panel.classes.remove('show');
  _loginButton.classes.remove('disabled');
  subs.forEach((s) => s.cancel());
}

void _setSection(HtmlElement section) {
  _panel.querySelectorAll('section.show').classes.remove('show');
  section.classes.add('show');
}

void _updateCreateButton() {
  _registerButton.disabled = !_emailInput.value.contains('@') ||
      _passwordInput.value.length < pwLengthMin ||
      _passwordInput.value != _confirmInput.value;
}
