import 'dart:async';

import 'package:dungeonclub/reactive/set.dart';

class SelectionSystem<E> extends ReactiveSet<E> {
  E? _active;
  E? get active => _active;
  set active(E? value) {
    final previousActive = _active;
    if (value == previousActive) return;

    _active = value;
    _activeController.add(SetActiveEvent(previousActive, value));
  }

  final _activeController =
      StreamController<SetActiveEvent<E>>.broadcast(sync: true);
  Stream<SetActiveEvent<E>> get onSetActive => _activeController.stream;

  @override
  void clear() {
    super.clear();
    active = null;
  }
}

class SetActiveEvent<E> {
  final E? previousActive;
  final E? active;

  SetActiveEvent(this.previousActive, this.active);
}
