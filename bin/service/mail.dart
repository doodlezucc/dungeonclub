import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dungeonclub/environment.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:path/path.dart' as path;

import '../server.dart';
import 'service.dart';

class MailService extends StartableService {
  MailConnection? connection;

  @override
  Future<void> startService() async {
    final enableMailService = await MailCredentials.credentialsFile.exists();

    if (!enableMailService) {
      final exeName = Environment.isCompiled
          ? path.basename(Platform.executable)
          : 'dart bin/server.dart';

      return print('Mailing system not enabled '
          '(run "$exeName mail" to walk through the activation process)');
    } else {
      final credentials = await MailCredentials.load();
      connection = MailConnection(credentials);
    }
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
    if (connection == null) return false;

    var content = await File('mail/$layoutFile').readAsString();
    content = content.replaceAll('\$CODE', code);

    final message = Message()
      ..from = connection!.systemAddress
      ..recipients.add(email)
      ..subject = subject
      ..html = content
      ..attachments.add(FileAttachment(File('web/images/icon32.png'))
        ..location = Location.inline
        ..cid = '<logo>');

    return connection!.sendMessage(message);
  }

  @override
  Future<void> dispose() async {
    await connection?.credentials.save();
  }
}

class MailConnection {
  final MailCredentials credentials;
  SmtpServer _smtpServer;

  Address get systemAddress => Address(credentials.user, 'Dungeon Club');

  MailConnection(this.credentials) : _smtpServer = credentials.toServerConfig();

  Future<void> _refreshCredentialsIfExpired() async {
    if (await credentials.refreshIfExpired()) {
      _smtpServer = credentials.toServerConfig();
    }
  }

  Future<bool> sendMessage(Message message) async {
    try {
      await _refreshCredentialsIfExpired();
      final sendReport = await send(message, _smtpServer);
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
}

class MailCredentials {
  static final credentialsFile = File('mail/gmail_credentials');

  final String user;
  final auth.ClientId clientId;
  auth.AccessCredentials _credentials;

  auth.AccessToken get accessToken => _credentials.accessToken;

  Duration get untilExpiry =>
      _credentials.accessToken.expiry.difference(DateTime.now()) -
      Duration(minutes: 1);

  MailCredentials({
    required this.user,
    required this.clientId,
    required auth.AccessCredentials credentials,
  }) : _credentials = credentials;

  MailCredentials.fromJson(json)
      : user = json['user'],
        clientId = auth.ClientId.fromJson(json['client']),
        _credentials = auth.AccessCredentials.fromJson(json['credentials']);

  SmtpServer toServerConfig() => gmailSaslXoauth2(user, accessToken.data);

  Future<bool> refreshIfExpired() async {
    if (untilExpiry.inMinutes <= 1) {
      _credentials =
          await auth.refreshCredentials(clientId, _credentials, httpClient);
      return true;
    }

    return false;
  }

  static Future<MailCredentials> load() async {
    final json = jsonDecode(await credentialsFile.readAsString());

    return MailCredentials.fromJson(json);
  }

  Future<void> save() async {
    final json = toJson();
    final jsonString = jsonEncode(json);

    await credentialsFile.create(recursive: true);
    await credentialsFile.writeAsString(jsonString);
  }

  Map<String, dynamic> toJson() => {
        'user': user,
        'client': clientId.toJson(),
        'credentials': _credentials.toJson(),
      };
}
