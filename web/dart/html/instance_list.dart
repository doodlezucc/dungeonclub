import 'dart:html';

import 'package:dungeonclub/reactive/list.dart';

import 'instance_component.dart';

class InstanceList<E extends InstanceComponent> extends ReactiveList<E> {
  final Element itemContainer;

  InstanceList(this.itemContainer);

  @override
  void add(E value) {
    itemContainer.append(value.htmlRoot);
    super.add(value);
  }

  @override
  void remove(E value) {
    value.dispose();
    super.remove(value);
  }
}
