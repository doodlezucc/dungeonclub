import 'dart:async';
import 'dart:io';

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:meta/meta.dart';

String _mailAddress;
SmtpServer _smtpServer;
SmtpServer get smtpServer => _smtpServer;

final pendingFeedback = <Feedback>[];

class Feedback {
  final String type;
  final String content;
  final String account;
  final String game;

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
  var file = File('mail/gmail_credentials');
  if (!await file.exists()) {
    await file.create(recursive: true);
    stderr.writeln('Missing gmail SMTP credentials at ${file.path}');
    return exit(1);
  }
  var lines = await file.readAsLines();
  // ignore: deprecated_member_use
  _smtpServer = gmail(lines[0], lines[1]);
  _mailAddress = lines[0] + '@gmail.com';

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
    subject: 'Activate your D&D Interactive Account',
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
  @required String email,
  @required String code,
  @required String subject,
  @required String layoutFile,
}) async {
  var content = await File('mail/$layoutFile').readAsString();
  content = content.replaceAll('\$CODE', code);

  final message = Message()
    ..from = Address(_mailAddress, 'D&D Interactive')
    ..recipients.add(email)
    ..subject = subject
    ..html = content
    ..attachments.add(FileAttachment(File('web/images/icon32.png'))
      ..location = Location.inline
      ..cid = '<logo>');

  return _sendMessage(message);
}

Future<bool> _sendFeedbackMail() async {
  pendingFeedback.sort((a, b) => a.type.compareTo(b.type));

  final message = Message()
    ..from = Address(_mailAddress, 'D&D Interactive')
    ..recipients.add(_mailAddress)
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
  try {
    final sendReport = await send(message, smtpServer);
    print('Message sent: ' + sendReport.toString());
    return true;
  } on MailerException catch (e) {
    print('Message not sent.');
    print(e.message);
    for (var p in e.problems) {
      print('Problem: ${p.code}: ${p.msg}');
    }
    return false;
  }
}
