import 'dart:async';
import 'dart:convert';
import 'dart:html';

import '../main.dart';
import 'server_actions.dart';

WebSocket _webSocket;
final _waitForOpen = Completer();

void wsConnect() {
  var secure = window.location.href.startsWith('https') ? 's' : '';

  _webSocket = WebSocket('ws$secure://localhost:7070/ws')
    ..onOpen.listen((e) => _waitForOpen.complete())
    ..onClose.listen((e) => print('CLOSE'))
    ..onError.listen((e) => print(e))
    ..onMessage.listen((e) {
      print('MSG: ' + e.data);
      if (e.data is String && e.data.startsWith('{"action":')) {
        var parsed = jsonDecode(e.data);
        var action = parsed['action'];
        var params = parsed['params'];

        print('Action $action incoming');

        switch (action) {
          case GAME_MOVABLE_CREATE:
            return session.board.onMovableCreate(params);

          case GAME_MOVABLE_MOVE:
            return session.board.onMovableMove(params);
        }

        window.console.warn('Unhandled action!');
      }
    });
}

Future<void> send(dynamic message) async {
  await _waitForOpen.future;
  _webSocket.send(message);
}

Future<void> sendAction(String action, [Map<String, dynamic> params]) async {
  //if (!_waitForOpen.isCompleted) (await _waitForOpen.future);
  await _waitForOpen.future;

  var json = jsonEncode({
    'action': action,
    if (params != null) 'params': params,
  });
  _webSocket.send(json);
}

int _jobId = 0;

Future<dynamic> request(String action, [Map<String, dynamic> params]) async {
  await _waitForOpen.future;

  var myId = _jobId++;
  var json = jsonEncode({
    'id': myId,
    'action': action,
    if (params != null) 'params': params,
  });
  _webSocket.send(json);

  var msg = await _webSocket.onMessage.firstWhere(
      (msg) => msg.data is String && msg.data.startsWith('{"id":$myId,'));

  _jobId--;
  return jsonDecode(msg.data)['result'];
}
