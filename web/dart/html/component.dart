import 'dart:html';

import '../html_helpers.dart';

class Component<T extends Element> {
  final T htmlRoot;

  Component.element(this.htmlRoot);

  Component(String rootSelector) : htmlRoot = queryDom(rootSelector);
}
