import 'dart:async';
import 'dart:io';

import 'package:dungeonclub/actions.dart';
import 'package:graceful/graceful.dart';

import '../../connections.dart';
import '../../data.dart';
import 'file_processor.dart';

class MaintenanceSwitchService extends ScheduledFileProcessorService {
  int? shutdownTimestamp;
  bool get isShutownScheduled => shutdownTimestamp != null;

  MaintenanceSwitchService() : super(filePath: 'maintenance');

  @override
  Future<void> processFile(File file) async {
    var minutes = int.tryParse(await file.readAsString());

    if (minutes != null && minutes > 0) {
      var now = DateTime.now();
      var date = DateTime(now.year, now.month, now.day, now.hour, now.minute)
          .add(Duration(minutes: minutes));
      shutdownTimestamp = date.millisecondsSinceEpoch;

      _sendShutdown();
      _scheduleShutdownEvent();
      print('Scheduled shutdown for $date');

      interrupt();
    }
  }

  void _scheduleShutdownEvent() async {
    var now = DateTime.now().millisecondsSinceEpoch;
    await Future.delayed(Duration(milliseconds: shutdownTimestamp! - now));
    exitGracefully();
  }

  Map<String, dynamic> get jsonEntry => {'shutdown': shutdownTimestamp};

  void _sendShutdown() {
    for (var c in connections) {
      c.sendAction(MAINTENANCE, jsonEntry);
    }
  }
}

class AccountRemovalService extends ScheduledFileProcessorService {
  final ServerData serverData;

  AccountRemovalService({required this.serverData})
      : super(filePath: 'account');

  @override
  Future processFile(File file) async {
    var lines = await file.readAsLines();
    var changed = false;
    for (var l in lines) {
      if (l.isNotEmpty) {
        var acc = serverData.getAccount(l, alreadyEncrypted: !l.contains('@'));
        if (acc != null) {
          changed = true;
          var count = acc.ownedGames.length;
          await acc.delete();
          print('Deleted account ${acc.encryptedEmail} with $count games...');
        }
      }
    }

    if (changed) {
      await file.delete();
    }
  }
}
