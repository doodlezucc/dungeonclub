import 'dart:async';
import 'dart:html';

import 'package:dnd_interactive/actions.dart';

import '../../main.dart';
import '../communication.dart';
import 'panel_overlay.dart';

const pwLengthMin = 7;

final CodePanel registerPanel =
    CodePanel('#registerPanel', ACCOUNT_REGISTER, ACCOUNT_ACTIVATE);

final CodePanel resetPanel = CodePanel(
    '#resetPanel', ACCOUNT_RESET_PASSWORD, ACCOUNT_RESET_PASSWORD_ACTIVATE);

class CodePanel {
  final HtmlElement _panel;

  HtmlElement _sectionRegister;
  HtmlElement _sectionActivate;

  InputElement _emailInput;

  InputElement _passwordInput;

  InputElement _confirmInput;

  InputElement _codeInput;
  SpanElement _emailReader;

  ButtonElement _registerButton;
  ButtonElement _activateButton;

  ButtonElement _cancelButton;
  final ButtonElement _loginButton = querySelector('button#login');

  final String actionSend;
  final String actionVerify;

  CodePanel(String panelId, this.actionSend, this.actionVerify)
      : _panel = querySelector(panelId) {
    _sectionRegister = _panel.querySelector('.credentials');
    _sectionActivate = _panel.querySelector('.activate');

    _emailInput = _panel.querySelector('.email')
      ..onInput.listen((event) => _updateCreateButton());

    _passwordInput = _panel.querySelector('.password')
      ..onInput.listen((event) => _updateCreateButton());

    _confirmInput = _panel.querySelector('.confirm')
      ..onInput.listen((event) => _updateCreateButton());

    _codeInput = _panel.querySelector('.code');
    _emailReader = _panel.querySelector('.email-reader');

    _registerButton = _panel.querySelector('.send');
    _activateButton = _panel.querySelector('.activate-code');

    _cancelButton = _panel.querySelector('button.close');
  }

  Future<void> display() async {
    overlayVisible = true;
    _loginButton.classes.add('disabled');
    _emailInput.value = '';
    _passwordInput.value = '';
    _confirmInput.value = '';
    _updateCreateButton();

    var closer = Completer();
    var subs = [
      _registerButton.onClick.listen((event) async {
        _registerButton.disabled = true;

        var moveOn = await socket.request(actionSend, {
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
        var account = await socket.request(actionVerify, {
          'code': _codeInput.value,
        });
        if (account == false) return print("Sike! That's the wrong numba!");

        user.onActivate(account);
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
    overlayVisible = false;
  }

  void _setSection(HtmlElement section) {
    _panel.querySelectorAll('section.show').classes.remove('show');
    section.classes.add('show');
  }

  bool isValidPassword(InputElement pw, InputElement confirm) =>
      pw.value.length >= pwLengthMin && pw.value == confirm.value;

  void _updateCreateButton() {
    _registerButton.disabled = !_emailInput.value.contains('@') ||
        !isValidPassword(_passwordInput, _confirmInput);
  }
}
