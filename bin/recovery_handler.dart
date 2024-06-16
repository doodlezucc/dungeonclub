import 'dart:convert';
import 'dart:io';

import 'package:crypt/crypt.dart';

import 'connections.dart';
import 'data.dart';
import 'mail.dart';

class RecoveryHandler {
  static final _file = File('database/unrecovered-emails.json');

  static Set<String> _pendingEmailsWaitingForRecovery = {};
  static final activationCodes = <Connection, PasswordReset>{};

  static Future<void> init() async {
    if (!await _file.exists()) {
      return;
    }

    final fileContents = await _file.readAsString();
    _pendingEmailsWaitingForRecovery = Set.from(jsonDecode(fileContents));

    final pendingCount = _pendingEmailsWaitingForRecovery.length;
    print('$pendingCount mails are listed for recovery');
  }

  static Future<void> save() async {
    await _file
        .writeAsString(jsonEncode(_pendingEmailsWaitingForRecovery.toList()));
  }

  static bool isEmailAffectedByMemoryGapLoss(String emailAddress) {
    return _pendingEmailsWaitingForRecovery.contains(emailAddress);
  }

  static void onEmailPasswordManuallySet(String emailAddress) {
    final wasRemoved = _pendingEmailsWaitingForRecovery.remove(emailAddress);
    if (wasRemoved) {
      save();
    }
  }
}

extension RecoveryConnectionExtension on Connection {
  Future handleEventRestore(Map<String, dynamic> params) async {
    String email = params['email'];
    String password = params['password'];

    if (!RecoveryHandler.isEmailAffectedByMemoryGapLoss(email)) {
      return "This email address is not listed for recovery.";
    }

    final code = Connection.generateCode();
    RecoveryHandler.activationCodes[this] =
        PasswordReset(email, password, code);
    return await sendMailWithCode(
      subject: 'Code for your Account Reactivation',
      email: email,
      layoutFile: 'restore.html',
      code: code,
    );
  }

  Future handleEventRestoreActivate(Map<String, dynamic> params) async {
    final reset = RecoveryHandler.activationCodes[this];
    String code = params['code'];

    if (reset == null || code != reset.code) {
      throw 'Invalid activation code';
    }

    final acc = server.data.getAccount(reset.email)!;

    acc.setPassword(reset.password);
    RecoveryHandler.onEmailPasswordManuallySet(reset.email);

    RecoveryHandler.activationCodes.remove(this);
    tokenAccounts.removeWhere((s, a) => a == acc);
    print('An account has been restored! Yay!');
    return loginAccount(acc);
  }
}

class PlaceholderCrypt implements Crypt {
  static const HASH = 'PLACEHOLDER';

  @override
  String get hash => HASH;

  @override
  String toString() => HASH;

  @override
  bool match(String value) {
    return value == HASH;
  }

  @override
  int? get rounds => throw UnimplementedError();

  @override
  String get salt => throw UnimplementedError();

  @override
  String get type => throw UnimplementedError();
}

class PlaceholderAccount extends Account {
  PlaceholderAccount(ServerData data)
      : super(data, 'INVALID_EMAIL', 'INVALID_PASSWORD');

  @override
  final Crypt encryptedEmail = PlaceholderCrypt();

  @override
  Crypt encryptedPassword = PlaceholderCrypt();

  @override
  Future<void> delete() {
    throw UnimplementedError();
  }

  @override
  void setPassword(String password) {
    throw UnimplementedError();
  }
}
