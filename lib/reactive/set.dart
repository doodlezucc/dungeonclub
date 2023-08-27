import 'dart:async';

class ReactiveSet<E> extends Iterable<E> {
  final Set<E> _set = {};

  final _addController = StreamController<E>.broadcast(sync: true);
  Stream<E> get onAdd => _addController.stream;

  final _removeController = StreamController<E>.broadcast(sync: true);
  Stream<E> get onRemove => _removeController.stream;

  void add(E value) {
    _set.add(value);
    _addController.add(value);
  }

  void remove(E value) {
    _set.remove(value);
    _removeController.add(value);
  }

  void clear() {
    final copy = _set.toList();
    for (var item in copy) {
      _removeController.add(item);
    }
    _set.clear();
  }

  @override
  Iterator<E> get iterator => _set.iterator;
}
