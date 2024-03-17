import 'dart:async';

import 'package:meta/meta.dart';

abstract class Service {
  bool _isStarted = false;

  @mustBeOverridden
  @mustCallSuper
  FutureOr<void> start() async {
    if (_isStarted) return;

    _isStarted = true;
  }
}
