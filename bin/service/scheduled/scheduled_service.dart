import 'dart:async';
import 'dart:io';

import '../service.dart';

abstract class ScheduledService extends ServiceImpl {
  final Duration interval;
  bool _wasInterrupted = false;

  ScheduledService({required this.interval});

  @override
  Future<void> startService() async {
    while (!_wasInterrupted) {
      try {
        await onSchedule();
      } catch (err) {
        stderr.writeln('Error in scheduled service ($runtimeType)');
        stderr.writeln(err);
      }

      await Future.delayed(interval);
    }
  }

  void interrupt() {
    _wasInterrupted = true;
  }

  FutureOr<void> onSchedule();
}
