import 'dart:html';

import 'package:dnd_interactive/actions.dart';
import 'package:web_polymask/polygon_canvas.dart';

import '../communication.dart';
import 'board.dart';

class FogOfWar {
  final canvas =
      PolygonCanvas(querySelector('#board svg'), captureInput: false);

  void initFogOfWar(Board board) {
    canvas
      ..onChange = _onPolymaskChange
      ..acceptStartEvent = (ev) {
        return (ev is! MouseEvent) || (ev as MouseEvent).button == 0;
      }
      ..modifyPoint = (p) => p * (1 / board.scaledZoom);
  }

  void load(String data) async {
    if (data != null) {
      canvas.fromData(data);
      //TODO fix chrome/firefox SVG issues
    } else {
      canvas.clear();
    }
  }

  void _onPolymaskChange() {
    socket.sendAction(GAME_SCENE_FOG_OF_WAR, {'data': canvas.toData()});
  }
}
