import 'dart:async';
import 'dart:html';
import 'dart:math';

import 'package:dnd_interactive/actions.dart';
import 'package:meta/meta.dart';

import '../communication.dart';

final HtmlElement _panel = querySelector('#uploadPanel');
final ButtonElement _cancelButton = _panel.querySelector('button.close');

final HtmlElement _imgContainer = _panel.querySelector('div');

final FileUploadInputElement _uploadInput = _panel.querySelector('#imgUpload');

final ImageElement _img = _panel.querySelector('img');
final CanvasElement _canvas = _panel.querySelector('canvas');
final ButtonElement _uploadButton = _panel.querySelector('button[type=submit]');
final DivElement _crop = _panel.querySelector('#crop');
final SpanElement _dragText = _panel.querySelector('#dragText');

Point<double> get _imgSize =>
    Point(_img.width.toDouble(), _img.height.toDouble());

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

Point<T> clamp<T extends num>(Point<T> point, Point<T> pMin, Point<T> pMax,
    [num inset = 0]) {
  return Point<T>(min(max(point.x, pMin.x), pMax.x + inset),
      min(max(point.y, pMin.y), pMax.y + inset));
}

Point<T> clampMin<T extends num>(Point<T> point, Point<T> pMin) {
  return Point<T>(max(point.x, pMin.x), max(point.y, pMin.y));
}

Point<double> minSize = Point<double>(50, 50);

Point<double> _size = Point(400, 400);
Point<double> get size => _size;

bool _square;
bool _init = false;

void _initialize() {
  if (!_init) {
    _init = true;

    _uploadInput.onInput.listen((event) {
      if (_uploadInput.files.isNotEmpty) {
        _loadFileAsImage(_uploadInput.files[0]);
        _uploadInput.value = null;
      }
    });
    _imgContainer.onDrop.listen((e) {
      e.preventDefault();
      if (e.dataTransfer.files != null && e.dataTransfer.files.isNotEmpty) {
        _loadFileAsImage(e.dataTransfer.files[0]);
      }
    });

    _crop.onMouseDown.listen((e) async {
      e.preventDefault();
      HtmlElement clicked = e.target;
      var pos1 = position;
      var size1 = size;

      void Function(Point<double>) action;
      if (clicked != _crop) {
        var cursorCss = clicked.style.cursor + ' !important';
        document.body.style.cursor = cursorCss;
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
                var minimum =
                    min(maxSizeDiff.y, min(pos1.x, maxSizeDiff.x) * 2);
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

      var mouse1 = Point<double>(e.client.x, e.client.y);
      var subMove = window.onMouseMove.listen((e) {
        if (e.movement.magnitude == 0) return;
        var diff = Point<double>(e.client.x, e.client.y) - mouse1;

        action(diff);
      });

      await window.onMouseUp.first;

      document.body.style.cursor = '';
      _crop.style.cursor = '';
      await subMove.cancel();
    });
  }
}

void _resizeOutside() {
  var ctx = _canvas.context2D;
  ctx.clearRect(0, 0, _canvas.width, _canvas.height);
  ctx.fillStyle = '#000c';
  ctx.fillRect(0, 0, _canvas.width, position.y); // top
  ctx.fillRect(0, position.y, position.x, size.y); // left
  ctx.fillRect(position.x + size.x, position.y, _canvas.width, size.y); // right
  ctx.fillRect(0, position.y + size.y, _canvas.width, _canvas.height); // bottom
}

int _getMaxRes(String type) {
  switch (type) {
    case IMAGE_TYPE_SCENE:
      return 2048;
    case IMAGE_TYPE_PC:
    default:
      return 256;
  }
}

bool _isSquare(String type) {
  switch (type) {
    case IMAGE_TYPE_PC:
      return true;
    default:
      return false;
  }
}

Future<dynamic> display({
  @required String action,
  @required String type,
  Map<String, dynamic> extras,
  Blob initialImg,
}) async {
  _initialize();

  var maxRes = _getMaxRes(type);
  _square = _isSquare(type);

  if (initialImg == null) {
    _img.width = 0;
    _img.height = 0;
    _canvas.width = 0;
    _canvas.height = 0;
    _crop.classes.add('hide');
    _dragText.classes.remove('hide');
    _uploadButton.disabled = true;
  } else {
    _loadFileAsImage(initialImg);
  }

  _panel.classes.add('show');

  var completer = Completer();
  var subs = [
    _uploadButton.onClick.listen((_) async {
      _uploadButton.disabled = true;
      var result = await _upload(action, type, extras, maxRes);
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
      for (var file in e.clipboardData.files) {
        return _loadFileAsImage(file);
      }
    })
  ];

  if (initialImg == null) {
    _uploadInput.click();
  }

  var finalResult = await completer.future;
  subs.forEach((s) => s.cancel());
  _panel.classes.remove('show');
  return finalResult;
}

void _loadFileAsImage(Blob blob) async {
  _img.src = Url.createObjectUrlFromBlob(blob);
  await _img.onLoad.first;

  var width = _img.naturalWidth;
  var height = _img.naturalHeight;
  var max = 300;

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
        _square ? max.toDouble() : width,
        _square ? max.toDouble() : height,
      ));
  _dragText.classes.add('hide');
  _crop.classes.remove('hide');
  _uploadButton.disabled = false;
}

CanvasElement _imgToCanvas(int maxRes) {
  var x = position.x / _imgSize.x;
  var y = position.y / _imgSize.y;
  var w = size.x / _imgSize.x;
  var h = size.y / _imgSize.y;
  var nw = _img.naturalWidth;
  var nh = _img.naturalHeight;

  var dw = (w * nw).round();
  var dh = (h * nh).round();

  if (dw >= dh && dw > maxRes) {
    dh = (dh * maxRes / dw).round();
    dw = maxRes;
  }
  if (dh >= dw && dh > maxRes) {
    dw = (dw * maxRes / dh).round();
    dh = maxRes;
  }

  return CanvasElement(width: dw, height: dh)
    ..context2D.drawImageScaledFromSource(
        _img, x * nw, y * nh, w * nw, h * nh, 0, 0, dw, dh);
}

Future<dynamic> _upload(
    String action, String type, Map<String, dynamic> extras, int maxRes) async {
  var canvas = _imgToCanvas(maxRes);
  var blob = await canvas.toBlob('image/png');

  var reader = FileReader()..readAsDataUrl(blob);
  await reader.onLoadEnd.first;

  var png = (reader.result as String).substring(22);

  var json = <String, dynamic>{'type': type, 'data': png};
  if (extras != null) json.addAll(Map.from(extras));

  var result = await socket.request(action, json);
  return result;
}
