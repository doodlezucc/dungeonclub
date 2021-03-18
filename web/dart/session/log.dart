import 'dart:html';

final HtmlElement _log = querySelector('#log');

void gameLog(String s) async {
  var line = SpanElement()..innerHtml = s;
  _log.append(line);
  _log.scrollTop = _log.scrollHeight;

  await Future.delayed(Duration(seconds: 8));
  line.animate([
    {'opacity': 1},
    {'opacity': 0.6},
  ], 2000);
  line.classes.add('hidden');
}
