import 'dart:async';

import 'package:meta/meta.dart';

mixin Service {
  FutureOr<void> start();
}

abstract class ServiceImpl implements Service {
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
