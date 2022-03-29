String formatToHtml(
  String text, {
  String markdown = r'\*',
  String tag = 'b',
  String tagClass,
}) {
  // Match between markdown char
  var _regex = RegExp(markdown + r'.*?' + markdown);

  return text.replaceAllMapped(_regex, (match) {
    var part = match[0].substring(1, match[0].length - 1);
    return wrapAround(part, tag, tagClass);
  });
}

String wrapAround(String content, String tag, [String className]) {
  return [
    '<$tag',
    if (className != null) ' class="$className"',
    '>$content</$tag>',
  ].join();
}
