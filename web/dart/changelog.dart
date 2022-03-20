import 'dart:html';

import 'package:ambience/ambience.dart';

import 'communication.dart';
import 'formatting.dart';

final changelog = Changelog().._init();

class Changelog {
  HtmlElement get button => querySelector('#changelogButton');
  HtmlElement get root => querySelector('#changelog');

  void _init() {
    button
      ..onClick.listen((_) => button.classes.toggle('active'))
      ..onMouseLeave.listen((_) => button.classes.remove('active'));
  }

  Future<void> fetch() async {
    var uri = Uri.parse(getFile('CHANGELOG.md', cacheBreak: false));
    var content = await httpClient.read(uri);
    _parseContent(content);
  }

  void _parseContent(String s) {
    root.querySelectorAll('li').forEach((element) => element.remove());

    var versions = s.split('##').where((e) => e.trim().isNotEmpty);
    for (var v in versions) {
      var change = _parseChange(v);
      root.append(LIElement()
        ..text = change.title
        ..children
            .addAll(change.changes.map((e) => LIElement()..innerHtml = e)));
    }
  }

  LoggedChange _parseChange(String s) {
    var lines = s.split('\n').map((l) => l.trim()).toList();

    return LoggedChange(
        lines[0],
        lines
            .skip(1)
            .where((line) => line.isNotEmpty)
            .map((e) => formatToHtml(e.substring(2), 'i')));
  }
}

class LoggedChange {
  final String title;
  final Iterable<String> changes;

  LoggedChange(this.title, this.changes);
}
