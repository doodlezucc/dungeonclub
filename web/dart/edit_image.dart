import 'dart:html';

import 'package:meta/meta.dart';

HtmlElement registerEditImage(
  HtmlElement editImg, {
  @required Future<String> Function([Blob initialFile]) upload,
  void Function(String src) onSuccess,
}) {
  ImageElement img = editImg.querySelector('img');

  editImg.onDragEnter.listen((_) async {
    await Future.delayed(Duration(milliseconds: 1));
    editImg.classes.add('drag');
  });
  editImg.onDragLeave.listen((_) => editImg.classes.remove('drag'));

  void uploadAndUpdate([Blob initialFile]) async {
    editImg.classes.remove('drag');
    var src = await upload(initialFile);
    if (src != null) {
      img.src = src.startsWith('data')
          ? src
          : '$src?${DateTime.now().millisecondsSinceEpoch}';
      if (onSuccess != null) onSuccess(src);
    }
  }

  return editImg
    ..onClick.listen((_) => uploadAndUpdate())
    ..onDrop.listen((e) {
      e.preventDefault();
      if (e.dataTransfer.files != null && e.dataTransfer.files.isNotEmpty) {
        uploadAndUpdate(e.dataTransfer.files[0]);
      }
    });
}
