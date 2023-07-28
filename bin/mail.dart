import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dungeonclub/environment.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:path/path.dart' as path;
import 'package:prompts/prompts.dart' as prompts;

import 'server.dart';

SmtpServer? _smtpServer;

final pendingFeedback = <Feedback>[];
final credFile = File('mail/gmail_credentials');

class Feedback {
  final String type;
  final String content;
  final String? account;
  final String? game;

  Feedback(this.type, this.content, this.account, this.game);

  @override
  String toString() {
    var s = 'Type: ${type.toUpperCase()}';
    if (account != null) {
      s += '\nAccount: $account';
    }
    if (game != null) {
      s += '\nGame: $game';
    }
    return '$s\n$content';
  }
}

Future<void> initializeMailServer() async {
  if (!await credFile.exists()) {
    var exe = Environment.isCompiled
        ? path.basename(Platform.executable)
        : 'dart bin/server.dart';

    return print('Mailing system not enabled '
        '(run "$exe mail" to walk through the activation process)');
  }

  await MailCredentials.load();

  Timer.periodic(Duration(minutes: 10), (_) => sendPendingFeedback());
}

Future<bool> sendPendingFeedback() async {
  if (pendingFeedback.isNotEmpty) {
    return _sendFeedbackMail();
  }
  return true;
}

Future<bool> sendVerifyCreationMail(String email, String code) {
  return sendMailWithCode(
    subject: 'Activate your Dungeon Club Account',
    email: email,
    layoutFile: 'activate.html',
    code: code,
  );
}

Future<bool> sendResetPasswordMail(String email, String code) {
  return sendMailWithCode(
    subject: 'Reset Password',
    email: email,
    layoutFile: 'reset.html',
    code: code,
  );
}

Future<bool> sendMailWithCode({
  required String email,
  required String code,
  required String subject,
  required String layoutFile,
}) async {
  if (_smtpServer == null) return false;

  var content = await File('mail/$layoutFile').readAsString();
  content = content.replaceAll('\$CODE', code);

  final message = Message()
    ..from = Address(MailCredentials.user, 'Dungeon Club')
    ..recipients.add(email)
    ..subject = subject
    ..html = content
    ..attachments.add(FileAttachment(File('web/images/icon32.png'))
      ..location = Location.inline
      ..cid = '<logo>');

  return _sendMessage(message);
}

Future<bool> _sendFeedbackMail() async {
  if (_smtpServer == null) return false;

  pendingFeedback.sort((a, b) => a.type.compareTo(b.type));

  final message = Message()
    ..from = Address(MailCredentials.user, 'Dungeon Club')
    ..recipients.add(MailCredentials.user)
    ..subject = 'Feedback'
    ..text = '${pendingFeedback.length} new feedback letters:\n\n' +
        pendingFeedback.join('\n------------------------------------\n\n');

  if (await _sendMessage(message)) {
    pendingFeedback.clear();
    return true;
  }
  return false;
}

Future<bool> _sendMessage(Message message) async {
  if (_smtpServer == null) return false;

  try {
    await MailCredentials.refreshCredentials();
    final sendReport = await send(message, _smtpServer!);
    print('Message sent: ' + sendReport.toString());
    return true;
  } on MailerException catch (e) {
    print('Message not sent.');
    print(e.message);

    var lines = e.message.split('\n');
    if (lines.length == 2 && lines[1].startsWith('<')) {
      print(utf8.decode(base64Decode(lines[1].substring(2))));
    }

    for (var p in e.problems) {
      print('Problem: ${p.code}: ${p.msg}');
    }
    return false;
  }
}

Future<void> closeMailServer() async {
  if (_smtpServer == null) return;

  await MailCredentials.save();
}

class MailCredentials {
  static late String user;
  static late auth.ClientId clientId;
  static late auth.AccessCredentials creds;

  static Duration get untilExpiry =>
      creds.accessToken.expiry.difference(DateTime.now()) -
      Duration(minutes: 1);

  static Future<void> configure(
    String user,
    auth.ClientId clientId,
    auth.AccessCredentials creds,
  ) async {
    MailCredentials.user = user;
    MailCredentials.clientId = clientId;
    MailCredentials.creds = creds;
  }

  static Future<void> refreshCredentials() async {
    if (untilExpiry.inMinutes <= 1) {
      creds = await auth.refreshCredentials(clientId, creds, httpClient);
    }

    _resetSmtpConfig();
  }

  static void _resetSmtpConfig() {
    _smtpServer = gmailSaslXoauth2(user, creds.accessToken.data);
  }

  static Future<void> load() async {
    var json = jsonDecode(await credFile.readAsString());
    await configure(
      json['user'],
      auth.ClientId.fromJson(json['client']),
      auth.AccessCredentials.fromJson(json['credentials']),
    );
    await refreshCredentials();
    print('Signed into mail OAuth client');
  }

  static Future<void> save() async {
    var json = {
      'user': user,
      'client': clientId.toJson(),
      'credentials': creds.toJson(),
    };

    await credFile.create(recursive: true);
    await credFile.writeAsString(jsonEncode(json));
  }
}

Future<void> setupMailAuth() async {
  print('''
-- Create an OAuth 2.0 client --

1. Register a new project in the Google Cloud Console at
   https://console.cloud.google.com/projectcreate

2. Go to "Credentials" and create a new OAuth client ID (application type: "Desktop app")

3. Copy and paste the newly created client ID and secret to proceed
''');

  var clientID = prompts.get('Client ID');
  var clientSecret = prompts.get('Client secret');
  var user = prompts.get('Email address');

  var client = auth.ClientId(clientID, clientSecret);
  var scopes = ['https://mail.google.com/'];
  var creds = await auth.obtainAccessCredentialsViaUserConsent(
    client,
    scopes,
    httpClient,
    (url) {
      print('\nPlease go to the following URL and grant access:');
      print('$url');
    },
  );

  await MailCredentials.configure(user, client, creds);
  await MailCredentials.save();
  httpClient.close();
  print('\nAuthorization complete! Emails can now be sent from $user');
  exit(0);
}
