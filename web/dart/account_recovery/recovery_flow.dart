import 'dart:html';

import 'package:dungeonclub/actions.dart';

import '../panels/code_panel.dart';

class AccountRecoveryFlow {
  static const emailQueryParameteterName = 'recover';

  static final _restoreAccountPanel = CodePanel(
    '#restoreAccountPanel',
    ACCOUNT_RESTORE,
    ACCOUNT_RESTORE_ACTIVATE,
  );

  static void checkUrlForAction() {
    final uri = Uri.parse(window.location.href);

    final emailAddressQueryParam =
        uri.queryParameters[emailQueryParameteterName];

    if (emailAddressQueryParam != null) {
      _handleAccountRecoveryLanding(
        emailAddressToRecover: emailAddressQueryParam,
      );
    }
  }

  static void _handleAccountRecoveryLanding({
    required String emailAddressToRecover,
  }) {
    _restoreAccountPanel.display(defaultEmailAddress: emailAddressToRecover);
  }
}
