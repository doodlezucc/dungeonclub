import 'dart:html';

HtmlElement icon(String id, {bool isBrand = false}) {
  final element = Element.tag('i') as HtmlElement;
  element.classes = [
    isBrand ? 'fab' : 'fas',
    'fa-$id',
  ];

  return element;
}

String iconHtml(String id) {
  return '<i class="fas fa-$id"></i>';
}

ButtonElement iconButton(String ico, {String? className, String? label}) =>
    ButtonElement()
      ..classes = {'icon', if (className != null) className}
      ..text = label
      ..append(icon(ico));
