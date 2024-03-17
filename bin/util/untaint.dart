import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';

const _maxFileSize = 1 * 1000 * 1000; // 1 MB
final _client = HttpClient();

Future<Response> untaint(
    Request req, Response Function(Request request) onError) async {
  var url = req.url.queryParameters['url'];

  if (url == null) {
    return onError(req);
  }

  var request = await _client.getUrl(Uri.parse(url));
  var response = await request.close();

  if (response.contentLength > _maxFileSize) {
    return onError(req);
  }

  var bytes = 0;
  var transformer = StreamTransformer<List<int>, List<int>>.fromHandlers(
    handleData: (data, sink) {
      bytes++;
      if (bytes > _maxFileSize) {
        sink.close();
      } else {
        sink.add(data);
      }
    },
  );

  return Response.ok(
    response.transform(transformer),
    headers: {
      'Content-Type': '${response.headers.contentType}',
    },
  );
}
