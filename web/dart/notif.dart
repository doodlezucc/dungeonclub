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
        e..append(_iconButton('times')..onClick.listen((e) => remove())));
  }

  ButtonElement _iconButton(String ico, [String className]) => ButtonElement()
    ..classes = {'icon', if (className != null) className}
    ..append(icon(ico));

  Future<bool> prompt() {
    var completer = Completer<bool>();
    e.append(_iconButton('check', 'good')
      ..onClick.listen((e) {
        completer.complete(true);
        remove();
      }));

    e.append(_iconButton('times', 'bad')
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
