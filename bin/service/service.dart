import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';

mixin Service {
  FutureOr<void> start();
}

abstract class StartableService implements Service {
  bool _isStarted = false;
  bool get isStarted => _isStarted;

  @mustCallSuper
  FutureOr<void> start() async {
    if (_isStarted) {
      return;
    }

    _isStarted = true;
    await startService();
  }

  FutureOr<void> startService();
}

abstract class ScheduledService extends StartableService {
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
