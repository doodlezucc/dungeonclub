import 'dart:html';

import 'package:dnd_interactive/actions.dart';
import 'package:web_polymask/polygon_canvas.dart';

import '../communication.dart';
import 'board.dart';

class FogOfWar {
  final canvas = PolygonCanvas(querySelector('#polymask'), captureInput: false);

  void initFogOfWar(Board board) {
    canvas
      ..onChange = _onPolymaskChange
      ..acceptStartEvent = (ev) {
        return (ev is! MouseEvent) || (ev as MouseEvent).button == 0;
      }
      ..modifyPoint = (p) => p * (1 / board.scaledZoom);
  }

  Future<void> load(String data) async {
    if (data != null) {
      canvas.fromData(data);
      await _fixSvgInit();
    } else {
      canvas.clear();
    }
  }

  // Force browsers to redraw SVG
  Future<void> _fixSvgInit() async {
    var maskRect = canvas.polyneg.children.first;

    Future<void> adjust(int x) async {
      maskRect.attributes['width'] = '$x%';
      maskRect.attributes['height'] = '$x%';
      await Future.delayed(Duration(milliseconds: 50));
    }

    var rect = canvas.root.parent.getBoundingClientRect();

    canvas.root.setAttribute('viewBox', '0 0 ${rect.width} ${rect.height}');
    for (var i = 0; i < 10; i++) {
      await adjust(99);
      await adjust(100);
    }
    canvas.root.removeAttribute('viewBox');
  }

  void _onPolymaskChange() {
    socket.sendAction(GAME_SCENE_FOG_OF_WAR, {'data': canvas.toData()});
  }
}
