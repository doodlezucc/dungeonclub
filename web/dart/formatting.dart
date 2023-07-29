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
