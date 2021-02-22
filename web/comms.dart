import 'dart:async';
import 'dart:convert';

abstract class Socket {
  Stream get messageStream;
  Future<void> send(dynamic data);

  int _jobId = 0;

  Future<dynamic> request(String action, [Map<String, dynamic> params]) async {
    var myId = _jobId++;
    var json = jsonEncode({
      'id': myId,
      'action': action,
      if (params != null) 'params': params,
    });
    await send(json);

    var msg = await messageStream.firstWhere(
        (data) => data is String && data.startsWith('{"id":$myId,'));

    _jobId--;
    return jsonDecode(msg)['result'];
  }

  Future<void> sendAction(String action, [Map<String, dynamic> params]) async {
    var json = jsonEncode({
      'action': action,
      if (params != null) 'params': params,
    });
    return send(json);
  }
}
