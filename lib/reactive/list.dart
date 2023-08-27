import 'dart:async';

class ReactiveList<E> extends Iterable<E> {
  final List<E> _list = [];

  final _addController = StreamController<E>.broadcast();
  Stream<E> get onAdd => _addController.stream;

  final _removeController = StreamController<E>.broadcast();
  Stream<E> get onRemove => _removeController.stream;

  void add(E value) {
    _list.add(value);
    _addController.add(value);
  }

  void remove(E value) {
    _list.remove(value);
    _removeController.add(value);
  }

  void clear() {
    for (var i = _list.length - 1; i >= 0; i--) {
      final item = _list.removeLast();
      _removeController.add(item);
    }
  }

  int indexOf(E element) {
    return _list.indexOf(element);
  }

  @override
  Iterator<E> get iterator => _list.iterator;

  operator [](int index) {
    return _list[index];
  }
}
