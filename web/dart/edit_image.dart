import 'dart:html';

import 'html_helpers.dart';
import 'panels/upload.dart';

HtmlElement registerEditImage(
  HtmlElement editImg, {
  required Future<String?> Function(MouseEvent ev, [Blob? initialFile]) upload,
  void Function(String src)? onSuccess,
}) {
  ImageElement img = editImg.queryDom('img');

  editImg.onDragEnter.listen((_) async {
    await Future.delayed(Duration(milliseconds: 1));
    editImg.classes.add('drag');
  });
  editImg.onDragLeave.listen((_) => editImg.classes.remove('drag'));

  void uploadAndUpdate(MouseEvent ev, [Blob? initialFile]) async {
    editImg.classes.remove('drag');
    var src = await upload(ev, initialFile);
    if (src != null) {
      img.src = src.startsWith('data')
          ? src
          : '$src?${DateTime.now().millisecondsSinceEpoch}';
      if (onSuccess != null) onSuccess(src);
    }
  }

  return editImg
    ..onLMB.listen((ev) => uploadAndUpdate(ev))
    ..onDrop.listen((ev) {
      ev.preventDefault();

      final droppedFiles = ev.dataTransfer.files;
      if (droppedFiles != null && droppedFiles.isNotEmpty) {
        uploadAndUpdate(ev, droppedFiles[0]);
      }
    });
}
