import 'dart:async';
import 'dart:io';

import 'package:dnd_interactive/actions.dart';

import 'connections.dart';
import 'server.dart';

class Maintainer {
  final File timeFile;
  int shutdownTime;

  Maintainer(String timestampFile) : timeFile = File(timestampFile);

  void autoCheckForScheduleFile() {
    Timer.periodic(Duration(seconds: 3), (_) => _checkForFile());
  }

  Future<void> _checkForFile() async {
    if (shutdownTime == null && await timeFile.exists()) {
      var minutes = int.tryParse(await timeFile.readAsString());

      if (minutes != null && minutes > 0) {
        var now = DateTime.now();
        var date = DateTime(now.year, now.month, now.day, now.hour, now.minute)
            .add(Duration(minutes: minutes));
        shutdownTime = date.millisecondsSinceEpoch;

        _sendShutdown();
        _waitForShutdown();
        print('Scheduled shutdown for $date');
      }
    }
  }

  void _waitForShutdown() async {
    var now = DateTime.now().millisecondsSinceEpoch;
    await Future.delayed(Duration(milliseconds: shutdownTime - now));
    onExit();
  }

  Map<String, dynamic> get jsonEntry => {'shutdown': shutdownTime};

  void _sendShutdown() {
    for (var c in connections) {
      c.sendAction(MAINTENANCE, jsonEntry);
    }
  }
}
