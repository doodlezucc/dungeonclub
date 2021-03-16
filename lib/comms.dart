import 'dart:async';
import 'dart:convert';

abstract class Socket {
  int _jobId = 0;

  Stream get messageStream;
  Future<void> send(dynamic data);
  Future handleAction(String action, [Map<String, dynamic> params]);

  StreamSubscription listen({void Function() onDone, Function onError}) =>
      messageStream.listen((data) async {
        var ds = data.toString();
        var cut = 200;
        print(ds.length <= cut ? ds : ds.substring(0, cut));
        if (data is String) {
          if (data[0] == '{') {
            var json = jsonDecode(data);

            var result = await handleAction(json['action'], json['params']);

            var id = json['id'];
            if (id != null) {
              await send('r' + jsonEncode({'id': id, 'result': result}));
            }
          }
        }
      }, onDone: onDone, onError: onError);

  Future request(String action, [Map<String, dynamic> params]) async {
    var myId = _jobId++;
    var json = jsonEncode({
      'id': myId,
      'action': action,
      if (params != null) 'params': params,
    });
    await send(json);

    String msg = await messageStream.firstWhere(
        (data) => data is String && data.startsWith('r{"id":$myId,'),
        orElse: () => null);

    _jobId--;
    return msg != null ? jsonDecode(msg.substring(1))['result'] : null;
  }

  Future<void> sendAction(String action, [Map<String, dynamic> params]) async {
    var json = jsonEncode({
      'action': action,
      if (params != null) 'params': params,
    });
    return send(json);
  }
}
