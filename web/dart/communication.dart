import 'dart:convert';
import 'dart:html';

final WebSocket webSocket = WebSocket('ws$_secure://localhost:7070/ws')
  ..onOpen.listen((e) => print('OPEN'))
  ..onClose.listen((e) => print('CLOSE'))
  ..onError.listen((e) => print(e))
  ..onMessage.listen((e) => print('MSG: ' + e.data));

String get _secure => window.location.href.startsWith('https') ? 's' : '';

void wsConnect() {
  webSocket;
}

void send(dynamic message) {
  webSocket.send(message);
}

int _jobId = 0;

Future<dynamic> request(String action, {Map<String, String> params}) async {
  var myId = _jobId++;
  print('Sending job $myId');

  var json = jsonEncode({'id': myId, 'action': action, 'params': params});
  webSocket.send(json);

  var msg = await webSocket.onMessage.firstWhere(
      (msg) => msg.data is String && msg.data.startsWith('{"id":$myId,'));

  _jobId--;
  print('Received response for job $myId!');
  return jsonDecode(msg.data)['result'];
}
