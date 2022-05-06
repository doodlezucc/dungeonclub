import 'dart:async';
import 'dart:convert';

import 'dart:math';

final confidentialRegex = RegExp(r'email|password|token|gameJoin');
const msgPrintLength = 200;
const maxMsgLength = 1024 * 1024 * 20;

abstract class Socket {
  final _jobs = <int>[];

  Stream get messageStream;
  Future<void> send(dynamic data);
  Future handleAction(String action, [Map<String, dynamic> params]);

  String modifyLog(String message) => message;

  StreamSubscription listen({void Function() onDone, Function onError}) =>
      messageStream.listen((data) async {
        if (data is String) {
          var s = data;
          var short =
              s.length <= msgPrintLength ? s : s.substring(0, msgPrintLength);

          if (!confidentialRegex.hasMatch(short)) {
            print(modifyLog(short));
          }

          if (s[0] == '{') {
            if (s.length >= maxMsgLength) {
              print('Warning: Long websocket message (${s.length} chars)');

              if (!short.startsWith('{"id"')) return;

              print('shortening');
              // Shorten json string to only contain message id
              s = short.substring(0, max(1, short.indexOf('"params"') + 10)) +
                  '}}';
              print(s);
            }

            var json = jsonDecode(s);

            var result = await handleAction(json['action'], json['params']);

            var id = json['id'];
            if (id != null) {
              await send('r' + jsonEncode({'id': id, 'result': result}));
            }
          }
        } else {
          handleBinary(data);
        }
      }, onDone: onDone, onError: onError);

  void handleBinary(data);

  Future request(String action, [Map<String, dynamic> params]) async {
    var myId = _jobs.isEmpty ? 0 : _jobs.last + 1;
    _jobs.add(myId);

    var json = jsonEncode({
      'id': myId,
      'action': action,
      if (params != null) 'params': params,
    });
    await send(json);

    String msg = await messageStream.firstWhere(
        (data) => data is String && data.startsWith('r{"id":$myId,'),
        orElse: () => null);

    _jobs.remove(myId);
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
