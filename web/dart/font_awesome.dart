import 'dart:html';

HtmlElement icon(String id, {bool isBrand = false}) {
  return Element.tag('i')
    ..classes = [
      isBrand ? 'fab' : 'fas',
      'fa-$id',
    ];
}

ButtonElement iconButton(String ico, {String className, String label}) =>
    ButtonElement()
      ..classes = {'icon', if (className != null) className}
      ..text = label
      ..append(icon(ico));
