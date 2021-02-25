import 'dart:html';

HtmlElement icon(String id) => Element.tag('i')..className = 'fas fa-$id';

ButtonElement iconButton(String ico, [String className]) => ButtonElement()
  ..classes = {'icon', if (className != null) className}
  ..append(icon(ico));
