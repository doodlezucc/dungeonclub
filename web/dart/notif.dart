import 'dart:async';
import 'dart:html';

import 'html_helpers.dart';

class HtmlNotification {
  static final _parent = queryDom('#notifications') as HtmlElement;
  final HtmlElement e;

  HtmlNotification(String msg)
      : e = DivElement()
          ..className = 'notification'
          ..append(SpanElement()..innerHtml = msg);

  void display() {
    _parent.append(
        e..append(iconButton('times')..onClick.listen((e) => remove())));
  }

  Future<bool> prompt() {
    var completer = Completer<bool>();
    e.append(iconButton('check', className: 'good')
      ..onClick.listen((e) {
        completer.complete(true);
        remove();
      }));

    e.append(iconButton('times', className: 'bad')
      ..onClick.listen((e) {
        completer.complete(false);
        remove();
      }));

    _parent.append(e);
    return completer.future;
  }

  void remove() {
    e.remove();
  }
}
