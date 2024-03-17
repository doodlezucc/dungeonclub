import 'dart:async';

import 'package:mailer/mailer.dart';

import 'mail.dart';
import 'service.dart';

class FeedbackPushService extends ScheduledService {
  final MailService mailService;
  final pendingFeedback = <Feedback>[];

  FeedbackPushService(this.mailService)
      : super(interval: Duration(minutes: 10));

  @override
  Future<void> onSchedule() async {
    await sendPendingFeedback();
  }

  @override
  Future<void> dispose() async {
    await sendPendingFeedback();
  }

  Future<bool> sendPendingFeedback() async {
    if (pendingFeedback.isNotEmpty) {
      return _sendFeedbackMail();
    }
    return true;
  }

  Future<bool> _sendFeedbackMail() async {
    final connection = mailService.connection;
    if (connection == null) {
      return false;
    }

    pendingFeedback.sort((a, b) => a.type.compareTo(b.type));

    final message = Message()
      ..from = mailService.connection!.systemAddress
      ..recipients.add(mailService.connection!.systemAddress.mailAddress)
      ..subject = 'Feedback'
      ..text = '${pendingFeedback.length} new feedback letters:\n\n' +
          pendingFeedback.join('\n------------------------------------\n\n');

    if (await connection.sendMessage(message)) {
      pendingFeedback.clear();
      return true;
    } else {
      return false;
    }
  }
}

class Feedback {
  static const validTypes = ['feature', 'bug', 'account', 'other'];

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
