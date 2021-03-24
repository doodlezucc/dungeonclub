import 'dart:async';
import 'dart:convert';

import 'dart:math';

final confidentialRegex = RegExp(r'email|password|token');
const msgPrintLength = 200;
const maxMsgLength = 1024 * 1024 * 1;

abstract class Socket {
  int _jobId = 0;

  Stream get messageStream;
  Future<void> send(dynamic data);
  Future handleAction(String action, [Map<String, dynamic> params]);

  StreamSubscription listen({void Function() onDone, Function onError}) =>
      messageStream.listen((data) async {
        var ds = data.toString();
        var short =
            ds.length <= msgPrintLength ? ds : ds.substring(0, msgPrintLength);

        if (!confidentialRegex.hasMatch(short)) {
          print(short);
        }

        if (data is String) {
          if (data[0] == '{') {
            if (data.length >= maxMsgLength) {
              print('Warning: Long websocket message (${data.length} chars)');

              if (!short.startsWith('{"id"')) return;

              // Shorten json string to only contain message id
              data = short.substring(0, min(1, short.indexOf(',') - 1)) + '}';
            }

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
