import 'dart:io';

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

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

Future<bool> sendVerifyCreationMail(String email, String code) async {
  var content = await File('mail/activate.html').readAsString();
  content = content.replaceAll('\$CODE', code);

  final message = Message()
    ..from = Address(_mailAddress, 'D&D Interactive')
    ..recipients.add(email)
    ..subject = 'Activate your D&D Interactive Account'
    ..html = content;

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
