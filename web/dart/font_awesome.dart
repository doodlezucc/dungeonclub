import 'dart:html';

HtmlElement icon(String id) => Element.tag('i')..className = 'fas fa-$id';

ButtonElement iconButton(String ico, {String className, String label}) =>
    ButtonElement()
      ..classes = {'icon', if (className != null) className}
      ..text = label
      ..append(icon(ico));
