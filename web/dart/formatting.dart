// Match between asterisks
final _regex = RegExp(r'\*.*?\*');

String formatToHtml(String text, [String tag = 'b']) {
  return text.replaceAllMapped(_regex, (match) {
    var part = match[0].substring(1, match[0].length - 1);
    return wrapAround(part, tag);
  });
}

String wrapAround(String content, String tag) {
  return '<$tag>$content</$tag>';
}
