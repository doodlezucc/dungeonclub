import 'dart:html';

import 'component.dart';

class ColorPalette extends Component {
  void Function(int hue) onSelect;

  ColorPalette(
    Element htmlRoot, {
    required List<int> hues,
    required this.onSelect,
  }) : super.element(htmlRoot) {
    for (var hue in hues) {
      final tile = DivElement()
        ..className = 'hue'
        ..style.setProperty('--hue', '$hue')
        ..onClick.listen((_) {
          onSelect(hue);
        });

      htmlRoot.append(tile);
    }
  }
}
