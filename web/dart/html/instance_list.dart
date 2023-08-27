import 'dart:async';
import 'dart:html';

import 'instance_component.dart';

class InstanceList<E extends InstanceComponent> extends Iterable<E> {
  final Element itemContainer;
  final List<E> _list = [];

  final _addController = StreamController<E>.broadcast();
  Stream<E> get onAdd => _addController.stream;

  final _removeController = StreamController<E>.broadcast();
  Stream<E> get onRemove => _removeController.stream;

  InstanceList(this.itemContainer);

  void add(E value) {
    itemContainer.append(value.htmlRoot);
    _list.add(value);
    _addController.add(value);
  }

  void remove(E value) {
    value.dispose();
    _list.remove(value);
    _removeController.add(value);
  }

  void clear() {
    for (var i = _list.length - 1; i >= 0; i--) {
      final item = _list.removeLast();
      _removeController.add(item);
    }
  }

  @override
  Iterator<E> get iterator => _list.iterator;
}
