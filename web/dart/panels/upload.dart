import 'dart:async';
import 'dart:html';
import 'dart:math';

import 'package:dnd_interactive/actions.dart';

import '../communication.dart';

final HtmlElement _panel = querySelector('#uploadPanel');

final HtmlElement _imgContainer = _panel.querySelector('div')
  ..onDrop.listen((e) {
    e.preventDefault();
    if (e.dataTransfer.files != null && e.dataTransfer.files.isNotEmpty) {
      _loadFileAsImage(e.dataTransfer.files[0]);
    }
  });

final FileUploadInputElement _uploadInput = _panel.querySelector('#imgUpload')
  ..onInput.listen((event) {
    if (_uploadInput.files.isNotEmpty) {
      _loadFileAsImage(_uploadInput.files[0]);
    }
  });

final ImageElement _img = _panel.querySelector('img');
final CanvasElement _canvas = _panel.querySelector('canvas');
final ButtonElement _uploadButton = _panel.querySelector('button[type=submit]');
final DivElement _crop = _panel.querySelector('#crop');

Point<double> get _imgSize =>
    Point(_img.width.toDouble(), _img.height.toDouble());

Point<double> _position;
Point<double> get position => _position;
set position(Point<double> p) {
  _position = clamp(p, Point(0, 0), _imgSize - size);
  _crop.style.left = '${_position.x}px';
  _crop.style.top = '${_position.y}px';
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
set size(Point<double> size) {
  _size = clampMin(size, minSize);
  _crop.style.width = '${size.x}px';
  _crop.style.height = '${size.y}px';
  _resizeOutside();
}

bool _init = false;

void _initialize() {
  if (!_init) {
    _init = true;
    _uploadInput.title = '';
    _imgContainer.title = '';
    _crop.onMouseDown.listen((e) async {
      e.preventDefault();
      HtmlElement clicked = e.target;
      var pos1 = position;
      var size1 = size;

      void Function(Point<double>) action;
      if (clicked != _crop) {
        var cursorCss = clicked.style.cursor;
        document.body.style.cursor = cursorCss;
        _crop.style.cursor = cursorCss;

        var classes = clicked.classes;

        action = (diff) {
          var x = pos1.x;
          var y = pos1.y;
          var width = size1.x;
          var height = size1.y;

          var maxPosDiff = size1 - minSize;

          if (classes.contains('top')) {
            var v = min(diff.y, maxPosDiff.y);
            y += v;
            height -= v;
          }
          if (classes.contains('right')) width += diff.x;
          if (classes.contains('bottom')) height += diff.y;
          if (classes.contains('left')) {
            var v = min(diff.x, maxPosDiff.x);
            x += v;
            width -= v;
          }

          size = Point(width, height);
          position = Point(x, y);
        };
      } else {
        action = (diff) {
          position = pos1 + diff;
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
  ctx.fillStyle = '#000a';
  ctx.fillRect(0, 0, _canvas.width, position.y); // top
  ctx.fillRect(0, position.y, position.x, size.y); // left
  ctx.fillRect(position.x + size.x, position.y, _canvas.width, size.y); // right
  ctx.fillRect(0, position.y + size.y, _canvas.width, _canvas.height); // bottom
}

Future<String> display(
    {String type = IMAGE_TYPE_PC, Map<String, dynamic> extras}) async {
  _initialize();
  _panel.classes.add('show');

  var completer = Completer<String>();

  StreamSubscription sub1;
  sub1 = _uploadButton.onClick.listen((event) async {
    _uploadButton.disabled = true;
    var result = await _upload(type, extras);
    if (result != null) {
      await sub1.cancel();
      completer.complete(result);
    }
    _uploadButton.disabled = false;
  });

  return await completer.future;
}

void _loadFileAsImage(File file) async {
  _img.src = Url.createObjectUrlFromBlob(file);
  await _img.onLoad.first;
  print('loaded');

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
  position = Point(0, 0);
  size = Point(max.toDouble(), max.toDouble());
}

void _imgToCanvas() {
  var ctx = _canvas.context2D;
  ctx.drawImageScaled(_img, 0, 0, _canvas.width, _canvas.height);
}

Future<String> _upload(String type, Map<String, dynamic> extras) async {
  _imgToCanvas();
  var blob = await _canvas.toBlob('image/png');

  var reader = FileReader()..readAsDataUrl(blob);
  await reader.onLoadEnd.first;

  var png = (reader.result as String).substring(22);

  var json = <String, dynamic>{'type': type, 'data': png};
  if (extras != null) json.addAll(Map.from(extras));

  var imgPath = await socket.request(IMAGE_UPLOAD, json);
  if (imgPath != null) {
    _panel.classes.remove('show');
  }
  return imgPath;
}
