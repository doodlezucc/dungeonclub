import 'dart:async';
import 'dart:html';

import 'package:dungeonclub/actions.dart';

import '../../main.dart';
import '../communication.dart';
import '../html_helpers.dart';
import 'panel_overlay.dart';

const pwLengthMin = 7;

final CodePanel registerPanel =
    CodePanel('#registerPanel', ACCOUNT_REGISTER, ACCOUNT_ACTIVATE);

final CodePanel resetPanel = CodePanel(
    '#resetPanel', ACCOUNT_RESET_PASSWORD, ACCOUNT_RESET_PASSWORD_ACTIVATE);

class CodePanel {
  final HtmlElement _panel;

  late HtmlElement _sectionRegister;
  late HtmlElement _sectionActivate;

  late InputElement _emailInput;

  late InputElement _passwordInput;

  late InputElement _confirmInput;

  late InputElement _codeInput;
  late SpanElement _emailReader;

  late ButtonElement _registerButton;
  late ButtonElement _activateButton;

  late HtmlElement _errorText1;
  late HtmlElement _errorText2;

  late ButtonElement _cancelButton;
  final ButtonElement _loginButton = queryDom('button#login');

  final String actionSend;
  final String actionVerify;

  CodePanel(String panelId, this.actionSend, this.actionVerify)
      : _panel = queryDom(panelId) {
    _sectionRegister = _panel.queryDom('.credentials');
    _sectionActivate = _panel.queryDom('.activate');

    _emailInput = _panel.queryDom('.email')
      ..onInput.listen((event) => _updateCreateButton());

    _passwordInput = _panel.queryDom('.password')
      ..onInput.listen((event) => _updateCreateButton());

    _confirmInput = _panel.queryDom('.confirm')
      ..onInput.listen((event) => _updateCreateButton());

    _codeInput = _panel.queryDom('.code')
      ..onInput.listen((_) {
        _activateButton.disabled = _codeInput.value!.length != 5;
      });
    _emailReader = _panel.queryDom('.email-reader');

    _registerButton = _panel.queryDom('.send');
    _activateButton = _panel.queryDom('.activate-code');

    _errorText1 = _sectionRegister.queryDom('p.bad');
    _errorText2 = _sectionActivate.queryDom('p.bad');

    _cancelButton = _panel.queryDom('button.close');
  }

  Future<void> display() async {
    overlayVisible = true;
    _loginButton.classes.add('disabled');
    _emailInput.value = '';
    _passwordInput.value = '';
    _confirmInput.value = '';
    _errorText1.text = '';
    _errorText2.text = '';
    _updateCreateButton();

    var closer = Completer();
    var subs = [
      _registerButton.onClick.listen((event) async {
        _registerButton.disabled = true;

        var moveOn = await socket.request(actionSend, {
          'email': _emailInput.value,
          'password': _passwordInput.value,
        });

        // Yes. I actually DO have to use "== true"!
        // moveOn can be a string. Checkmate.
        if (moveOn == true) {
          _emailReader.text = _emailInput.value;
          _activateButton.disabled = true;
          _setSection(_sectionActivate);
          _codeInput
            ..value = ''
            ..focus();
          blockPageExit = true;
        } else {
          _errorText1.text = moveOn;
          _registerButton.disabled = false;
        }
      }),
      _activateButton.onClick.listen((event) async {
        _errorText2.text = '';
        var account = await socket.request(actionVerify, {
          'code': _codeInput.value,
        });
        if (account == null) {
          _errorText2.text = 'Invalid code!';
          return;
        }

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
    blockPageExit = false;
  }

  void _setSection(HtmlElement section) {
    _panel.querySelectorAll('section.show').classes.remove('show');
    section.classes.add('show');
  }

  bool isValidPassword(InputElement pw, InputElement confirm) =>
      pw.value!.length >= pwLengthMin && pw.value == confirm.value;

  void _updateCreateButton() {
    _registerButton.disabled = !_emailInput.value!.contains('@') ||
        !isValidPassword(_passwordInput, _confirmInput);
  }
}
