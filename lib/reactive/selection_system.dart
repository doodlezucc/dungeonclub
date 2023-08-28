import 'dart:async';

import 'package:async/async.dart';
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

  Stream<bool> observe(E element) => StreamGroup.merge([
        onAdd.where((e) => e == element).map((_) => true),
        onRemove.where((e) => e == element).map((_) => false),
      ]);

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
