import 'dart:async';
import 'dart:io';

import 'package:dungeonclub/actions.dart';
import 'package:graceful/graceful.dart';

import '../connections.dart';
import 'scheduled_file_processor_service.dart';

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
