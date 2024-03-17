import 'dart:async';
import 'dart:io';

import 'package:dungeonclub/actions.dart';
import 'package:graceful/graceful.dart';

import '../../connections.dart';
import 'file_processor.dart';

class Maintainer extends ScheduledFileProcessor {
  int? shutdownTime;

  Maintainer(super.server, super.timestampFile);

  @override
  Future processFile(File file) async {
    var minutes = int.tryParse(await file.readAsString());

    if (minutes != null && minutes > 0) {
      var now = DateTime.now();
      var date = DateTime(now.year, now.month, now.day, now.hour, now.minute)
          .add(Duration(minutes: minutes));
      shutdownTime = date.millisecondsSinceEpoch;

      _sendShutdown();
      _waitForShutdown();
      print('Scheduled shutdown for $date');
      return true;
    }
  }

  void _waitForShutdown() async {
    var now = DateTime.now().millisecondsSinceEpoch;
    await Future.delayed(Duration(milliseconds: shutdownTime! - now));
    exitGracefully();
  }

  Map<String, dynamic> get jsonEntry => {'shutdown': shutdownTime};

  void _sendShutdown() {
    for (var c in connections) {
      c.sendAction(MAINTENANCE, jsonEntry);
    }
  }
}

class AccountMaintainer extends ScheduledFileProcessor {
  AccountMaintainer(super.server, super.filePath);

  @override
  Future processFile(File file) async {
    var lines = await file.readAsLines();
    var changed = false;
    for (var l in lines) {
      if (l.isNotEmpty) {
        var acc = server.data.getAccount(l, alreadyEncrypted: !l.contains('@'));
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
