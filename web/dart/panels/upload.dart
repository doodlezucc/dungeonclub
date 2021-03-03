import 'dart:async';
import 'dart:html';

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

Future<String> display(
    {String type = IMAGE_TYPE_PC, Map<String, dynamic> extras}) async {
  _panel.classes.add('show');
  _uploadInput.title = '';
  _imgContainer.title = '';

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

void _loadFileAsImage(File file) {
  _img.src = Url.createObjectUrlFromBlob(file);
  _imgToCanvas();
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
