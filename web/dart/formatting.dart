// Match between asterisks
final _regex = RegExp(r'\*.*?\*');

String formatToHtml(String text, [String tag = 'b']) {
  return text.replaceAllMapped(_regex, (match) {
    var boldPart = match[0].substring(1, match[0].length - 1);
    return '<$tag>$boldPart</$tag>';
  });
}
