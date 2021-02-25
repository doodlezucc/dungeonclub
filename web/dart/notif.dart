import 'dart:async';
import 'dart:html';

import 'font_awesome.dart';

class HtmlNotification {
  static final HtmlElement _parent = querySelector('#notifications');
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
    e.append(iconButton('check', 'good')
      ..onClick.listen((e) {
        completer.complete(true);
        remove();
      }));

    e.append(iconButton('times', 'bad')
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
