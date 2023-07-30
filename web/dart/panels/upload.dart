import 'dart:async';
import 'dart:html';
import 'dart:math';

import 'package:dungeonclub/actions.dart';
import 'package:dungeonclub/comms.dart';
import 'package:dungeonclub/limits.dart';
import 'package:dungeonclub/point_json.dart';
import 'package:grid_space/grid_space.dart';

import '../../main.dart';
import '../communication.dart';
import '../html_helpers.dart';
import 'context_menu.dart';
import 'dialog.dart';
import 'panel_overlay.dart';

extension ElementLeftClickDown on Element {
  Stream<MouseEvent> get onLMB => onMouseDown.where((ev) => ev.button == 0);
}

final HtmlElement _panel = queryDom('#uploadPanel');
final ButtonElement _cancelButton = _panel.queryDom('button.close');

final HtmlElement _imgBox = _panel.queryDom('div');

final FileUploadInputElement _uploadInput = _panel.queryDom('#imgUpload');

final ImageElement _img = _panel.queryDom('img');
final CanvasElement _canvas = _panel.queryDom('canvas');
final ButtonElement _uploadButton = _panel.queryDom('button[type=submit]');
final DivElement _crop = _panel.queryDom('#crop');
final SpanElement _dragText = _panel.queryDom('#dragText');

final DivElement _assetPanel = queryDom('#assetPanel');
final DivElement _assetGrid = queryDom('#assetGrid');

Point<double> get _imgSize =>
    Point(_img.width!.toDouble(), _img.height!.toDouble());

Point<double> _position = Point(0, 0);
Point<double> get position => _position;

void setPosAndSize(Point<double> p, Point<double> s) {
  p = Point(p.x.roundToDouble(), p.y.roundToDouble());
  _position = clamp(p, Point(0, 0), _imgSize - size);
  _size = clamp(s, minSize, _imgSize - position);
  _position = clamp(p, Point(0, 0), _imgSize - size);

  _crop.style.left = '${_position.x}px';
  _crop.style.top = '${_position.y}px';
  _crop.style.width = '${_size.x}px';
  _crop.style.height = '${_size.y}px';

  _resizeOutside();
}

Point<double> minSize = Point<double>(50, 50);

Point<double> _size = Point(400, 400);
Point<double> get size => _size;

bool _square = false;
bool _init = false;

const thresholdStorageWarning = 5 * 1000000;

int _usedStorage = 0;
int get usedStorage => _usedStorage;
set usedStorage(int bytes) {
  _usedStorage = bytes;

  final percentage = '${100 * bytes / mediaBytesPerCampaign}%';

  querySelectorAll('.used-storage').forEach(
    (e) => (e as InputElement)
      ..style.setProperty('--v', percentage)
      ..min = '0'
      ..max = '$mediaBytesPerCampaign'
      ..valueAsNumber = bytes,
  );

  final storageLeft = mediaBytesPerCampaign - bytes;
  final displayWarning = storageLeft <= thresholdStorageWarning;

  queryDom('#storageWarning').classes.toggle('hidden', !displayWarning);

  querySelectorAll('.storage-used').forEach((e) => e.text = bytesToMB(bytes));
  querySelectorAll('.storage-left')
      .forEach((e) => e.text = bytesToMB(storageLeft));
  querySelectorAll('.storage-max')
      .forEach((e) => e.text = '${mediaBytesPerCampaign ~/ 1000000}');
}

void _initialize() {
  _init = true;

  _uploadInput.onInput.listen((event) {
    final files = _uploadInput.files!;

    if (files.isNotEmpty) {
      _loadFileAsImage(files[0]);
      _uploadInput.value = null;
    }
  });

  // Styling on file drag
  _imgBox.onDragEnter.listen((_) async {
    await Future.delayed(Duration(milliseconds: 1));
    _imgBox.classes.add('drag');
  });
  _imgBox.onDragLeave.listen((_) => _imgBox.classes.remove('drag'));

  _imgBox.onDrop.listen((e) {
    _imgBox.classes.remove('drag');
    e.preventDefault();

    final droppedFiles = e.dataTransfer.files;

    if (droppedFiles != null && droppedFiles.isNotEmpty) {
      _loadFileAsImage(droppedFiles[0]);
    } else {
      var regex = RegExp(r'https?:\S+(?=")');
      String? preferred;

      var matches = e.dataTransfer.types!.expand((t) {
        var data = e.dataTransfer.getData(t);
        var parts = regex.allMatches(data).map((s) => s[0]!);

        if (parts.isNotEmpty && t == 'text/html') preferred = parts.first;

        return parts.isNotEmpty ? parts : [data];
      }).toList();

      if (matches.isNotEmpty) {
        var resolved = preferred ??
            matches.firstWhere(
              (s) => !s.contains('http', 5),
              orElse: () => matches.first,
            );
        _loadSrcAsImage(resolved);
      }
    }
  });

  _crop.onMouseDown.listen((e) async {
    e.preventDefault();
    final clicked = e.target as HtmlElement;
    var pos1 = position;
    var size1 = size;

    void Function(Point<double>) action;
    if (clicked != _crop) {
      var cursorCss = clicked.style.cursor + ' !important';
      document.body!.style.cursor = cursorCss;
      _crop.style.cursor = cursorCss;

      var classes = clicked.classes;
      var t = classes.contains('top');
      var r = classes.contains('right');
      var l = classes.contains('left');
      var b = classes.contains('bottom');

      action = (diff) {
        var x = pos1.x;
        var y = pos1.y;
        var width = size1.x;
        var height = size1.y;

        var maxPosDiff = size1 - minSize;
        var minPosDiff = pos1 * -1;

        if (_square) {
          var maxSizeDiff = _imgSize - size1 - pos1;
          double v;
          if (t) {
            if (r) {
              var maximum = min(maxSizeDiff.x, pos1.y);
              v = max(min(max(diff.x, -diff.y), maximum), -maxPosDiff.x);
            } else if (l) {
              var minimum = min(pos1.x, pos1.y);
              v = max(min(max(-diff.x, -diff.y), minimum), -maxPosDiff.x);
              x -= v;
            } else {
              var minimum = min(pos1.y, min(pos1.x, maxSizeDiff.x) * 2);
              v = max(min(-diff.y, minimum), -maxPosDiff.x);
              x -= (v / 2);
            }
            y -= v;
          } else if (b) {
            if (r) {
              var maximum = min(maxSizeDiff.x, maxSizeDiff.y);
              v = max(min(max(diff.x, diff.y), maximum), -maxPosDiff.x);
            } else if (l) {
              var minimum = min(pos1.x, maxSizeDiff.y);
              v = max(min(max(-diff.x, diff.y), minimum), -maxPosDiff.x);
              x -= v;
            } else {
              var minimum = min(maxSizeDiff.y, min(pos1.x, maxSizeDiff.x) * 2);
              v = max(min(diff.y, minimum), -maxPosDiff.x);
              x -= (v / 2);
            }
          } else if (r) {
            var minimum = min(min(pos1.y, maxSizeDiff.y) * 2, maxSizeDiff.x);
            v = max(min(diff.x, minimum), -maxPosDiff.y);
            y -= (v / 2);
          } else {
            var minimum = min(min(pos1.y, maxSizeDiff.y) * 2, pos1.x);
            v = max(min(-diff.x, minimum), -maxPosDiff.y);
            x -= v;
            y -= (v / 2);
          }
          width += v;
          height += v;
        } else {
          if (t) {
            var v = min(max(diff.y, minPosDiff.y), maxPosDiff.y);
            y += v;
            height -= v;
          }
          if (r) width += diff.x;
          if (b) height += diff.y;
          if (l) {
            var v = min(max(diff.x, minPosDiff.x), maxPosDiff.x);
            x += v;
            width -= v;
          }
        }

        setPosAndSize(Point(x, y), Point(width, height));
      };
    } else {
      action = (diff) {
        setPosAndSize(pos1 + diff, size);
      };
    }

    final mouse1 = Point(e.client.x, e.client.y).cast<double>();
    final subMove = window.onMouseMove.listen((e) {
      if (e.movement.magnitude == 0) return;

      final diff = Point(e.client.x, e.client.y).cast<double>() - mouse1;

      action(diff);
    });

    await window.onMouseUp.first;

    document.body!.style.cursor = '';
    _crop.style.cursor = '';
    await subMove.cancel();
  });
}

void _resizeOutside() {
  final canvasWidth = _canvas.width!;
  final canvasHeight = _canvas.height!;

  var ctx = _canvas.context2D;
  ctx.clearRect(0, 0, canvasWidth, canvasHeight);
  ctx.fillStyle = '#000c';
  ctx.fillRect(0, 0, canvasWidth, position.y); // top
  ctx.fillRect(0, position.y, position.x, size.y); // left
  ctx.fillRect(position.x + size.x, position.y, canvasWidth, size.y); // right
  ctx.fillRect(0, position.y + size.y, canvasWidth, canvasHeight); // bottom
}

int _getMaxRes(String type) {
  switch (type) {
    case IMAGE_TYPE_MAP:
      return 1200;
    case IMAGE_TYPE_SCENE:
      return 8000;
    case IMAGE_TYPE_PC:
    default:
      return 256;
  }
}

bool _isSquare(String type) {
  switch (type) {
    case IMAGE_TYPE_PC:
    case IMAGE_TYPE_ENTITY:
      return true;
    default:
      return false;
  }
}

bool _upscale(String type) {
  switch (type) {
    case IMAGE_TYPE_MAP:
      return true;
    default:
      return false;
  }
}

final _displayCtrl = StreamController<int>.broadcast(sync: true);

Future _displayOffline({
  required String type,
  Blob? initialImg,
  required Future Function(String base64, int maxRes, bool upscale)
      processUpload,
  bool openDialog = true,
}) async {
  _displayCtrl.sink.add(0);
  if (!_init) {
    _initialize();
  }

  var maxRes = _getMaxRes(type);
  var upscale = _upscale(type);
  _square = _isSquare(type);

  if (initialImg == null) {
    _img.width = 0;
    _img.height = 0;
    _canvas.width = 0;
    _canvas.height = 0;
    _crop.classes.add('hide');
    _dragText.classes.remove('hide');
    _uploadButton.disabled = true;

    if (openDialog) {
      _uploadInput.click();
      var event = await Future.any([
        _displayCtrl.stream.first,
        document.onMouseMove.map((event) => 0).first,
        _uploadInput.onInput.first,
      ]);
      if (event == 0) return null;
    }
  } else {
    _loadFileAsImage(initialImg);
  }

  overlayVisible = true;
  _panel.classes.add('show');

  final completer = Completer();
  final subs = [
    _uploadButton.onClick.listen((_) async {
      _uploadButton.disabled = true;
      final limit = mediaBytesPerCampaign - usedStorage;

      dynamic result;

      try {
        final base64 = await _imgToBase64(maxRes, upscale, limit);

        result = await processUpload(base64, maxRes, upscale);
      } on RangeError catch (_) {
        result = null;
      }

      if (result != null) {
        completer.complete(result);
      }
      _uploadButton.disabled = false;
    }),
    _cancelButton.onClick.listen((_) async {
      completer.complete();
    }),
    document.onPaste.listen((e) {
      e.preventDefault();

      final clipboardFiles = e.clipboardData?.files;

      if (clipboardFiles != null) {
        for (var file in clipboardFiles) {
          return _loadFileAsImage(file);
        }
      }
    })
  ];

  var finalResult = await completer.future;
  subs.forEach((s) => s.cancel());
  _panel.classes.remove('show');

  overlayVisible = false;
  return finalResult;
}

void _loadFileAsImage(Blob blob) {
  _loadSrcAsImage(Url.createObjectUrlFromBlob(blob));
}

void _loadSrcAsImage(String src) async {
  _uploadButton.disabled = true;
  _img.src = src;
  var event = await Future.any([_img.onLoad.first, _img.onError.first]);
  if (event.type == 'error') {
    if (src.startsWith('blob:')) return;

    // Use server to download an untainted version of the image
    _img.src = getFile('untaint') + '?url=$src';

    await _img.onLoad.first;
  }

  var width = _img.naturalWidth;
  var height = _img.naturalHeight;
  var max = window.innerHeight! ~/ 2;

  if (width > height) {
    width = width * max ~/ height;
    height = max;
  } else {
    height = height * max ~/ width;
    width = max;
  }

  _img.width = width;
  _img.height = height;
  _canvas.width = width;
  _canvas.height = height;
  setPosAndSize(
      Point(0, 0),
      Point(
        (_square ? max : width).toDouble(),
        (_square ? max : height).toDouble(),
      ));
  _dragText.classes.add('hide');
  _crop.classes.remove('hide');
  _uploadButton.disabled = false;
}

CanvasElement _imgToCanvas(int maxRes, bool upscale) {
  var x = position.x / _imgSize.x;
  var y = position.y / _imgSize.y;
  var w = size.x / _imgSize.x;
  var h = size.y / _imgSize.y;
  var nw = _img.naturalWidth;
  var nh = _img.naturalHeight;

  var dw = (w * nw).round();
  var dh = (h * nh).round();

  if (dw >= dh && (dw > maxRes || upscale)) {
    dh = (dh * maxRes / dw).round();
    dw = maxRes;
  } else if (dh >= dw && (dh > maxRes || upscale)) {
    dw = (dw * maxRes / dh).round();
    dh = maxRes;
  }

  return CanvasElement(width: dw, height: dh)
    ..context2D.drawImageScaledFromSource(
        _img, x * nw, y * nh, w * nw, h * nh, 0, 0, dw, dh);
}

Future<String> _emptyImageBase64(int width, int height) {
  var canvas = CanvasElement(width: width, height: height);
  canvas.context2D
    ..fillStyle = '#ffffff'
    ..fillRect(0, 0, width, height);
  return canvasToBase64(canvas);
}

Future<String> _imgToBase64(int maxRes, bool upscale, int sizeLimitInBytes) {
  var canvas = _imgToCanvas(maxRes, upscale);
  return canvasToBase64(canvas, sizeLimitInBytes: sizeLimitInBytes);
}

Future<String> canvasToBase64(
  CanvasElement canvas, {
  bool includeHeader = false,
  int? sizeLimitInBytes,
}) async {
  var blob = await canvas.toBlob('image/jpeg', 0.85);

  if (sizeLimitInBytes != null && blob.size > sizeLimitInBytes) {
    await _showUploadErrorDialog(blob.size);
    throw RangeError('Upload limit reached');
  }

  var reader = FileReader()..readAsDataUrl(blob);
  await reader.onLoadEnd.first;

  final dataUrl = reader.result as String;

  if (includeHeader || user.isInDemo) return dataUrl;

  return dataUrl.substring(23);
}

String bytesToMB(int bytes) {
  return (bytes / 1000000).toStringAsFixed(2);
}

/// Displays an error explaining the campaign storage situation.
Future<void> _showUploadErrorDialog(
  int bytesUpload, [
  int? bytesUsed,
  int? bytesMaximum,
]) async {
  bytesUsed ??= usedStorage;
  bytesMaximum ??= mediaBytesPerCampaign;

  final uploadMB = bytesToMB(bytesUpload);
  final usedMB = bytesToMB(bytesUsed);
  final maxMB = bytesToMB(bytesMaximum);

  final dialog = Dialog('Unable to upload');
  dialog.addParagraph(
    "The image you're trying to upload is too big (<b>$uploadMB MB</b>) "
    'and exceeds your campaign storage '
    '(used <b>$usedMB</b> / <b>$maxMB MB</b>)!',
  );
  await dialog.display();
}

Future _upload(String base64, String action, String type,
    Map<String, dynamic>? extras, int maxRes, bool upscale) async {
  if (user.isInDemo) {
    return {
      'image': base64,
    };
  }

  final json = <String, dynamic>{'type': type, 'data': base64};
  if (extras != null) json.addAll(Map.from(extras));

  try {
    final result = await socket.request(action, json);
    return result;
  } on ResponseError catch (err) {
    // Image can't be uploaded
    await _showUploadErrorDialog(
      err.context['bytesUpload'],
      err.context['bytesUsed'],
      err.context['bytesMaximum'],
    );
  }

  return null;
}

Future<String?> _displayAssetPicker(String type) async {
  _assetGrid.children.clear();
  _assetPanel.classes.add('show');
  overlayVisible = true;

  final previewImage = ASSET_PREVIEWS[type];
  final tmp = ImageElement(src: previewImage);
  await tmp.onLoad.first;

  final tileSize = tmp.width!;
  final tiles = tmp.height! ~/ tileSize;

  final completer = Completer<String>();

  for (var i = 0; i < tiles; i++) {
    var img = DivElement()
      ..style.backgroundImage = 'url(${tmp.src})'
      ..style.backgroundPositionY = '${-i * 100}%'
      ..onClick.listen((_) => completer.complete('asset/$type/$i'));
    _assetGrid.append(img);
  }

  var result = await Future.any([
    completer.future,
    _assetPanel.queryDom('.close').onClick.map((_) => null).first,
  ]);

  _assetPanel.classes.remove('show');
  overlayVisible = false;
  return result;
}

Future display({
  required MouseEvent event,
  required String type,
  String? action,
  Map<String, dynamic>? extras,
  Blob? initialImg,
  Future Function(String base64, int maxRes, bool upscale)? processUpload,
  void Function(bool v)? onPanelVisible,
  Element? simulateHoverClass,
}) async {
  var visible = (bool v) => onPanelVisible != null ? onPanelVisible(v) : null;
  var openDialog = true;

  if (initialImg == null) {
    var menu = ContextMenu();

    var assets = -1;
    var empty = -1;
    if (type == IMAGE_TYPE_PC || type == IMAGE_TYPE_SCENE) {
      assets = menu.addButton('Pick from Assets', 'image');
    }

    menu.addButton('Upload Image', 'upload');
    var dragDrop = menu.addButton('Drag & Drop', 'hand-pointer');

    if (type == IMAGE_TYPE_MAP) {
      empty = menu.addButton('Empty Canvas', 'sticky-note');
    }

    var result = await menu.display(event, simulateHoverClass);
    if (result == null) return;

    var maxRes = _getMaxRes(type);
    var upscale = _upscale(type);

    if (result == assets) {
      visible(true);
      var asset = await _displayAssetPicker(type);
      visible(false);
      if (asset == null) return null;

      if (processUpload != null) {
        return await processUpload(asset, maxRes, upscale);
      }

      return await _upload(asset, action!, type, extras, maxRes, upscale);
    } else if (result == empty) {
      var width = maxRes;
      var height = (width * 0.6).round();
      var base64 = await _emptyImageBase64(width, height);
      return await _upload(base64, action!, type, extras, maxRes, upscale);
    } else if (result == dragDrop) {
      openDialog = false;
    }
  }

  visible(true);

  var result = await _displayOffline(
    type: type,
    initialImg: initialImg,
    openDialog: openDialog,
    processUpload: processUpload ??
        (base64, maxRes, upscale) =>
            _upload(base64, action!, type, extras, maxRes, upscale),
  );

  visible(false);
  return result;
}
