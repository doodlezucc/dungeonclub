import 'dart:async';
import 'dart:html';

import 'component.dart';
import 'instance_list.dart';

abstract class InstanceComponent<T extends Element> extends Component<T> {
  late List<StreamSubscription> _listeners;

  InstanceComponent(T htmlRoot) : super.element(htmlRoot) {
    _listeners = initializeListeners();
  }

  List<StreamSubscription> initializeListeners() => [];

  void dispose(InstanceList list) {
    htmlRoot.remove();

    for (var listener in _listeners) {
      listener.cancel();
    }
  }
}
