import 'dart:convert';
import 'dart:html';
import 'dart:svg' as svg;

import 'package:dungeonclub/actions.dart';
import 'package:grid_space/grid_space.dart';
import 'package:web_polymask/brushes/lasso.dart';
import 'package:web_polymask/brushes/stroke.dart';
import 'package:web_polymask/brushes/tool.dart';
import 'package:web_polymask/polygon_canvas.dart';

import '../communication.dart';
import '../panels/dialog.dart';
import 'board.dart';

const _marginPx = 80;

class FogOfWar {
  static const tooltips = {
    StrokeBrush: '''Hold *left click* to add fog.
      Hold *shift* to erase.''',
    LassoBrush: '''Hold *left click* to outline a new shape or *click
      successively* to add<br>
      individual points (*rightclick* to close). Hold *shift* to erase.'''
  };

  final canvas = PolygonCanvas(
    querySelector('#polymask'),
    captureInput: false,
    cropMargin: _marginPx,
  )
    ..toolBrushStroke.shape = shapeCircle
    ..movementScale = 2;

  String get tooltip => tooltips[canvas.activeTool.runtimeType];
  Element get wrapper => querySelector('#polymaskWrapper');

  Element _toolbox;
  Element get toolbox => _toolbox ??= querySelector('#fogOfWar');
  Element get btnToolStroke => toolbox.querySelector('#fowStroke');
  Element get btnToolLasso => toolbox.querySelector('#fowLasso');
  Element get btnVisible => toolbox.querySelector('#fowPreview');
  Element get btnFill => toolbox.querySelector('#fowFill');
  Element get btnGrid => toolbox.querySelector('#fowGrid');

  String _currentData;
  bool _useGrid = true;
  bool get useGrid => _useGrid;

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
    btnVisible.onClick.listen((_) {
      opaque = !opaque;
      _saveSettings();
    });
    btnGrid.onClick.listen((_) {
      _useGrid = !_useGrid;
      applyUseGrid(board);
      _saveSettings();
    });

    final settings = window.localStorage['fogOfWar'];
    if (settings != null) {
      _settingsFromJson(board, jsonDecode(settings));
    }

    canvas.onSettingsChange = _saveSettings;
  }

  void _saveSettings() {
    final json = _settingsToJson();
    window.localStorage['fogOfWar'] = jsonEncode(json);
  }

  void applyUseGrid(Board board) {
    btnGrid.classes.toggle('active', useGrid);
    canvas.grid = canvas.grid = useGrid ? board.grid.grid : Grid.unclamped();
  }

  void _setTool(PolygonTool tool) {
    canvas.activeTool = tool;
    btnToolStroke.parent.querySelectorAll('.active').classes.remove('active');
    toolbox.querySelector('[tool=${tool.id}]').classes.add('active');
  }

  void _registerToolButton(Board board, Element btn, PolygonTool tool) {
    btn.onClick.listen((ev) {
      _setTool(tool);
      board.displayTooltip(tooltip);
    });
  }

  void load(String data) {
    _currentData = data ?? '';
    if (data != null) {
      canvas.fromData(data);
      _updateFillClearButtonDisplay();
    } else {
      canvas.clear();
    }
  }

  void fillAllToggle() async {
    if (canvas.isEmpty) {
      canvas.fillCanvas();
    } else {
      if (_currentData.length >= 30) {
        final confirm = await Dialog<bool>(
          'Clear Fog of War?',
          onClose: () => false,
          okText: 'Clear',
        ).addParagraph('''The fog of war in this scene will be reset and
            hidden areas will be revealed.''').display();

        if (!confirm) return;
      }

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
    _currentData = canvas.toData();
    socket.sendAction(GAME_SCENE_FOG_OF_WAR, {'data': _currentData});
    _updateFillClearButtonDisplay();
  }

  void _settingsFromJson(Board board, Map<String, dynamic> json) {
    if (board.session.isDM) opaque = json['opaque'];
    _useGrid = json['useGrid'];
    applyUseGrid(board);
    canvas.settingsFromJson(json);
    _setTool(canvas.activeTool);
  }

  Map<String, dynamic> _settingsToJson() => {
        'opaque': opaque,
        'useGrid': useGrid,
        ...canvas.settingsToJson(),
      };
}
