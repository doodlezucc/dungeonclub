import 'dart:async';
import 'dart:html';

import 'package:dungeonclub/iterable_extension.dart';

import 'component.dart';

class ColorPalette extends Component {
  final List<ColorTile> _tiles = [];

  late String _activeColor;
  String get activeColor => _activeColor;
  set activeColor(String color) {
    _activeColor = color;

    _deselectAll();

    final tile = _tiles.find((e) => e.color == color);
    tile?.styleSelected = true;
  }

  final _selectController = StreamController<String>.broadcast(sync: true);
  Stream<String> get onSelect => _selectController.stream;

  ColorPalette(Element htmlRoot, {required List<String> colors})
      : super.element(htmlRoot) {
    for (final color in colors) {
      final tile = ColorTile(color, onSelect: () {
        activeColor = color;
        _selectController.add(color);
      });

      _tiles.add(tile);
      htmlRoot.append(tile.htmlRoot);
    }

    activeColor = colors.first;
  }

  void _deselectAll() {
    for (final tile in _tiles) {
      tile.styleSelected = false;
    }
  }
}

class ColorTile extends Component {
  final String color;
  final void Function() onSelect;

  set styleSelected(bool value) {
    htmlRoot.classes.toggle('selected', value);
  }

  ColorTile(this.color, {required this.onSelect})
      : super.element(DivElement()) {
    htmlRoot
      ..className = 'color-tile'
      ..style.setProperty('--color', '$color')
      ..onClick.listen((_) {
        onSelect();
      });
  }
}
