import 'dart:async';
import 'dart:io';

import 'package:dungeonclub/actions.dart';
import 'package:graceful/graceful.dart';

import 'connections.dart';
import 'server.dart';

abstract class FileChecker {
  final File file;
  bool _locked = false;

  FileChecker(String file) : file = File(file);

  void autoCheckForFile() {
    Timer.periodic(Duration(seconds: 3), (_) => _checkForFile());
  }

  Future<void> _checkForFile() async {
    if (!_locked && await file.exists()) {
      _locked = true;
      if (await handleFileContents() == null) {
        _locked = false;
      }
    }
  }

  Future handleFileContents();
}

class Maintainer extends FileChecker {
  int shutdownTime;

  Maintainer(String timestampFile) : super(timestampFile);

  @override
  Future handleFileContents() async {
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
    await Future.delayed(Duration(milliseconds: shutdownTime - now));
    exitGracefully();
  }

  Map<String, dynamic> get jsonEntry => {'shutdown': shutdownTime};

  void _sendShutdown() {
    for (var c in connections) {
      c.sendAction(MAINTENANCE, jsonEntry);
    }
  }
}

class AccountMaintainer extends FileChecker {
  AccountMaintainer(String file) : super(file);

  @override
  Future handleFileContents() async {
    var lines = await file.readAsLines();
    var changed = false;
    for (var l in lines) {
      if (l.isNotEmpty) {
        var acc = data.getAccount(l, alreadyEncrypted: !l.contains('@'));
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
