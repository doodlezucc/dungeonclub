import 'dart:async';

import 'package:mailer/mailer.dart';

import 'service.dart';

final pendingFeedback = <Feedback>[];

class FeedbackPushService extends ScheduledService {
  FeedbackPushService() : super(interval: Duration(minutes: 10));

  @override
  Future<void> onSchedule() async {
    await sendPendingFeedback();
  }

  Future<bool> sendPendingFeedback() async {
    if (pendingFeedback.isNotEmpty) {
      return _sendFeedbackMail();
    }
    return true;
  }

  Future<bool> _sendFeedbackMail() async {
    pendingFeedback.sort((a, b) => a.type.compareTo(b.type));

    final message = Message()
      ..from = Address(MailCredentials.user, 'Dungeon Club')
      ..recipients.add(MailCredentials.user)
      ..subject = 'Feedback'
      ..text = '${pendingFeedback.length} new feedback letters:\n\n' +
          pendingFeedback.join('\n------------------------------------\n\n');

    if (await sendMessage(message)) {
      pendingFeedback.clear();
      return true;
    }
    return false;
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
