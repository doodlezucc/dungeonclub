import 'dart:convert';
import 'dart:html';

WebSocket _webSocket;

void wsConnect() {
  var secure = window.location.href.startsWith('https') ? 's' : '';

  _webSocket = WebSocket('ws$secure://localhost:7070/ws')
    ..onOpen.listen((e) => print('OPEN'))
    ..onClose.listen((e) => print('CLOSE'))
    ..onError.listen((e) => print(e))
    ..onMessage.listen((e) => print('MSG: ' + e.data));
}

void send(dynamic message) {
  _webSocket.send(message);
}

int _jobId = 0;

Future<dynamic> request(String action, {Map<String, String> params}) async {
  var myId = _jobId++;
  var json = jsonEncode({'id': myId, 'action': action, 'params': params});
  _webSocket.send(json);

  var msg = await _webSocket.onMessage.firstWhere(
      (msg) => msg.data is String && msg.data.startsWith('{"id":$myId,'));

  _jobId--;
  return jsonDecode(msg.data)['result'];
}
