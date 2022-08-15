import 'dart:html';
import 'dart:svg' as svg;

import 'package:dungeonclub/actions.dart';
import 'package:web_polymask/polygon_canvas.dart';

import '../communication.dart';
import 'board.dart';

const _marginPx = 80;

class FogOfWar {
  static const tooltip = '''Hold *left click* to draw continuous shapes or
      *click once* to<br> add single points (rightclick to close).
      Hold *shift* to make holes.''';

  final canvas = PolygonCanvas(
    querySelector('#polymask'),
    captureInput: false,
    cropMargin: _marginPx,
  );

  Element get wrapper => querySelector('#polymaskWrapper');
  Element get previewButton => querySelector('#fowPreview');

  bool get opaque => wrapper.classes.contains('opaque');
  set opaque(bool opaque) {
    wrapper.classes.toggle('opaque', opaque);
    previewButton.className =
        'fas fa-' + (opaque ? 'eye-low-vision' : 'eye active');
  }

  void initFogOfWar(Board board) {
    opaque = !board.session.isDM;
    canvas
      ..onChange = _onPolymaskChange
      ..acceptStartEvent = (ev) {
        return (ev is! MouseEvent) || (ev as MouseEvent).button == 0;
      }
      ..modifyPoint = (p) => p * (1 / board.scaledZoom);
  }

  void load(String data) {
    if (data != null) {
      canvas.fromData(data);
    } else {
      canvas.clear();
    }
  }

  // Force browsers to redraw SVG
  void fixSvgInit(int width, int height) {
    svg.RectElement maskRect = canvas.root.querySelector('mask rect');

    var unit = svg.Length.SVG_LENGTHTYPE_PX;
    maskRect.width.baseVal.newValueSpecifiedUnits(unit, width + _marginPx);
    maskRect.height.baseVal.newValueSpecifiedUnits(unit, height + _marginPx);
  }

  void _onPolymaskChange() {
    socket.sendAction(GAME_SCENE_FOG_OF_WAR, {'data': canvas.toData()});
  }
}
