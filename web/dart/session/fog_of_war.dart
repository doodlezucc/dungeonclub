import 'dart:html';
import 'dart:svg' as svg;

import 'package:dungeonclub/actions.dart';
import 'package:web_polymask/brushes/lasso.dart';
import 'package:web_polymask/brushes/stroke.dart';
import 'package:web_polymask/brushes/tool.dart';
import 'package:web_polymask/polygon_canvas.dart';

import '../communication.dart';
import 'board.dart';

const _marginPx = 80;

class FogOfWar {
  static const tooltips = {
    StrokeBrush: '''Hold *left click* to draw a stroke of fog.<br>
      Hold *shift* to make holes.''',
    LassoBrush: '''Hold *left click* to outline a new shape or <br>*click
      successively* to add individual points (rightclick to close).<br>
      Hold *shift* to make holes.'''
  };

  final canvas = PolygonCanvas(
    querySelector('#polymask'),
    captureInput: false,
    cropMargin: _marginPx,
  );

  String get tooltip => tooltips[canvas.activeTool.runtimeType];

  Element get wrapper => querySelector('#polymaskWrapper');

  Element _toolbox;
  Element get toolbox => _toolbox ??= querySelector('#fogOfWar');
  Element get btnToolStroke => toolbox.querySelector('#fowStroke');
  Element get btnToolLasso => toolbox.querySelector('#fowLasso');
  Element get btnVisible => toolbox.querySelector('#fowPreview');
  Element get btnFill => toolbox.querySelector('#fowFill');

  bool get opaque => wrapper.classes.contains('opaque');
  set opaque(bool opaque) {
    wrapper.classes.toggle('opaque', opaque);
    btnVisible.className =
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
    _updateFillClearButtonDisplay();
    _registerToolButton(board, btnToolStroke, canvas.toolBrushStroke);
    _registerToolButton(board, btnToolLasso, canvas.toolBrushLasso);
    _setTool(canvas.toolBrushStroke);
    btnFill.onClick.listen((_) => fillAllToggle());
    btnVisible.onClick.listen((_) => opaque = !opaque);
  }

  void _setTool(PolygonTool tool) {
    canvas.activeTool = tool;
    btnToolLasso.parent.querySelectorAll('.active').classes.remove('active');
    toolbox.querySelector('[tool=${tool.id}]').classes.add('active');
  }

  void _registerToolButton(Board board, Element btn, PolygonTool tool) {
    btn.onClick.listen((ev) {
      _setTool(tool);
      board.displayTooltip(tooltip);
    });
  }

  void load(String data) {
    if (data != null) {
      canvas.fromData(data);
      _updateFillClearButtonDisplay();
    } else {
      canvas.clear();
    }
  }

  void fillAllToggle() {
    if (canvas.isEmpty) {
      canvas.fillCanvas();
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

  void _updateFillClearButtonDisplay() {
    var icon = canvas.isEmpty ? 'paint-roller' : 'xmark';
    btnFill
      ..className = 'fas fa-$icon'
      ..querySelector('span').text =
          canvas.isEmpty ? 'Fill Scene' : 'Clear Scene';
  }

  void _onPolymaskChange() {
    socket.sendAction(GAME_SCENE_FOG_OF_WAR, {'data': canvas.toData()});
    _updateFillClearButtonDisplay();
  }
}
