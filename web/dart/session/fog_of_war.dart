import 'dart:html';
import 'dart:svg' as svg;

import 'package:dnd_interactive/actions.dart';
import 'package:web_polymask/polygon_canvas.dart';

import '../communication.dart';
import 'board.dart';

const _marginPx = 80;

class FogOfWar {
  final canvas = PolygonCanvas(
    querySelector('#polymask'),
    captureInput: false,
    cropMargin: _marginPx,
  );

  void initFogOfWar(Board board) {
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
