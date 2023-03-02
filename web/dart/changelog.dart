import 'dart:html';

import 'package:ambience/ambience.dart';
import 'package:intl/intl.dart';

import 'communication.dart';
import 'formatting.dart';

final changelog = Changelog().._init();

class Changelog {
  HtmlElement get button => querySelector('#changelogButton');
  HtmlElement get root => querySelector('#changelog');
  int lastChangeCount;
  int currentChangeCount;

  void _init() {
    button
      ..onClick.listen((ev) {
        var btnClick = ev.target == button;
        var show = button.classes.toggle('active', btnClick ? null : true);

        if (show) {
          button.classes.remove('new');
          _updateLastKnown();
        }
      })
      ..onMouseLeave.listen((_) => button.classes.remove('active'));

    var saved = window.localStorage['changelog'];
    if (saved != null) {
      lastChangeCount = int.tryParse(saved);
    } else {
      lastChangeCount = null;
    }
  }

  void _updateLastKnown() {
    lastChangeCount = currentChangeCount;
    window.localStorage['changelog'] = '$lastChangeCount';
  }

  Future<void> fetch() async {
    var uri = Uri.parse(getFile('CHANGELOG.md'));
    var content = await httpClient.read(uri);
    _applyContent(content);
  }

  void _applyContent(String s) {
    _applyLog(_parseContent(s));
  }

  void _applyLog(List<LoggedChange> changes) {
    root.querySelectorAll('li').forEach((element) => element.remove());

    currentChangeCount = changes.length;
    if (lastChangeCount == null) _updateLastKnown();

    var diff = currentChangeCount - lastChangeCount;
    if (diff > 0) button.classes.add('new');

    for (var change in changes) {
      var isNew = diff-- > 0;

      root.append(LIElement()
        ..innerHtml = change.title
        ..classes.addAll([if (isNew) 'new'])
        ..children
            .addAll(change.changes.map((e) => LIElement()..innerHtml = e)));
    }
  }

  List<LoggedChange> _parseContent(String s) {
    var changes = <LoggedChange>[];
    var versions = s.split('##').where((e) => e.trim().isNotEmpty);
    for (var v in versions) {
      var change = _parseChange(v);
      changes.add(change);
    }

    return changes;
  }

  LoggedChange _parseChange(String s) {
    var lines = s.split('\n').map((l) => l.trim()).toList();

    return LoggedChange(
        lines[0],
        lines.skip(1).where((line) => line.isNotEmpty).map((e) {
          return formatToHtml(formatToHtml(e.substring(2), tag: 'i'),
                  markdown: '`')
              .replaceAll('[', '<span>')
              .replaceAll(']', '</span>');
        }));
  }
}

class LoggedChange {
  final DateTime date;
  final Iterable<String> changes;
  String title;

  LoggedChange(String header, this.changes) : date = parseDate(header) {
    var outputFormat = DateFormat('MMM d, yyyy');
    title = outputFormat.format(date);

    var nameStart = header.indexOf(' ');
    if (nameStart >= 0) {
      var name = header.substring(nameStart + 1).trim();
      title += ' ' + wrapAround(name, 'i');
    }
  }

  static DateTime parseDate(String s) {
    var inputFormat = DateFormat('d-M-y');
    return inputFormat.parse(s, true);
  }
}
