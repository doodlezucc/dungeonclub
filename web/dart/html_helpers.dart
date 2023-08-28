import 'dart:html';

E queryDom<E extends Element>(String selectors) {
  return document.querySelector(selectors) as E;
}

extension ElementExtension on Element {
  E queryDom<E extends Element>(String selectors) {
    return this.querySelector(selectors) as E;
  }
}

Element icon(String id, {bool isBrand = false}) {
  final element = Element.tag('i');
  applyIconClasses(element, id);

  return element;
}

void applyIconClasses(Element element, String iconId, {bool isBrand = false}) {
  element.classes = [
    isBrand ? 'fab' : 'fas',
    'fa-$iconId',
  ];
}

String iconHtml(String id) {
  return '<i class="fas fa-$id"></i>';
}

ButtonElement iconButton(String ico, {String? className, String? label}) =>
    ButtonElement()
      ..classes = {'icon', if (className != null) className}
      ..text = label
      ..append(icon(ico));

String formatToHtml(
  String text, {
  String markdown = r'\*',
  String tag = 'b',
  String? tagClass,
}) {
  // Match between markdown char
  var _regex = RegExp(markdown + r'.*?' + markdown, dotAll: true);

  return text.replaceAllMapped(_regex, (match) {
    final matchText = match[0]!;
    final part = matchText.substring(1, matchText.length - 1);
    return wrapAround(part, tag, tagClass);
  });
}

String wrapAround(String content, String tag, [String? className]) {
  return [
    '<$tag',
    if (className != null) ' class="$className"',
    '>$content</$tag>',
  ].join();
}
