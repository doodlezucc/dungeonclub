import 'dart:html';

import 'font_awesome.dart';

class HtmlNotification {
  static final HtmlElement _parent = querySelector('#notifications');
  final HtmlElement e;

  HtmlNotification(String msg, {void Function(bool v) onClick})
      : e = DivElement()
          ..className = 'notification'
          ..append(SpanElement()..innerHtml = msg) {
    var hasHandler = onClick != null;

    if (hasHandler) {
      e.append(ButtonElement()
        ..className = 'icon good'
        ..append(icon('check'))
        ..onClick.listen((e) {
          onClick(true);
          remove();
        }));
    }

    e.append(ButtonElement()
      ..classes = {'icon', if (hasHandler) 'bad'}
      ..append(icon('times'))
      ..onClick.listen((e) {
        if (hasHandler) onClick(false);
        remove();
      }));

    _parent.append(e);
  }

  void remove() {
    e.remove();
  }
}
