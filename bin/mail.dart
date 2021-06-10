import 'dart:io';

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:meta/meta.dart';

String _mailAddress;
SmtpServer _smtpServer;
SmtpServer get smtpServer => _smtpServer;

Future<void> initializeMailServer() async {
  var file = File('mail/gmail_credentials');
  if (!await file.exists()) {
    await file.create(recursive: true);
    stderr.writeln('Missing gmail SMTP credentials at ${file.path}');
    return exit(1);
  }
  var lines = await file.readAsLines();
  _smtpServer = gmail(lines[0], lines[1]);
  _mailAddress = lines[0] + '@gmail.com';
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
    ..attachments.add(FileAttachment(File('web/sass/icon32.png'))
      ..location = Location.inline
      ..cid = '<logo>');

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
