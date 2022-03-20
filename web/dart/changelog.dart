import 'dart:html';

import 'package:ambience/ambience.dart';
import 'package:intl/intl.dart';

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
        ..innerHtml = change.title
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
  final DateTime date;
  final Iterable<String> changes;
  String title;

  LoggedChange(String header, this.changes) : date = parseDate(header) {
    var outputFormat = DateFormat('MMM d, yyyy');
    title = outputFormat.format(date);

    var name = header.substring(10).trim();
    if (name.isNotEmpty) {
      title += ' ' + wrapAround(name, 'i');
    }
  }

  static DateTime parseDate(String s) {
    var inputFormat = DateFormat('d-M-y');
    return inputFormat.parse(s);
  }
}
