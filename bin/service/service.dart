import 'dart:io';

import 'package:meta/meta.dart';

mixin Service {
  Future<void> start();
  Future<void> dispose();
}

abstract class StartableService implements Service {
  bool _isStarted = false;
  bool get isStarted => _isStarted;

  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;

  @mustCallSuper
  Future<void> start() async {
    if (_isStarted) {
      throw StateError('Service already started');
    }

    _isStarted = true;
    await startService();
  }

  @override
  Future<void> dispose() async {
    if (!_isStarted) return;

    if (_isDisposed) {
      throw StateError('Service already disposed');
    }

    _isDisposed = true;
    await disposeService();
  }

  Future<void> startService();
  Future<void> disposeService() async {}
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

  Future<void> onSchedule();
}
