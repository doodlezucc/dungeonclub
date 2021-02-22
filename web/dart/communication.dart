import 'dart:async';
import 'dart:convert';
import 'dart:html';

import '../comms.dart';
import 'action_handler.dart';

final socket = FrontSocket();

class FrontSocket extends Socket {
  WebSocket _webSocket;
  final _waitForOpen = Completer();

  void connect() {
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

          handleAction(action, params);
        }
      });
  }

  @override
  Stream get messageStream => _webSocket.onMessage.map((event) => event.data);

  @override
  Future<void> send(data) async {
    await _waitForOpen.future;
    _webSocket.send(data);
  }

  @override
  Future<dynamic> request(String action, [Map<String, dynamic> params]) async {
    await _waitForOpen.future;
    return super.request(action, params);
  }

  @override
  Future<void> sendAction(String action, [Map<String, dynamic> params]) async {
    await _waitForOpen.future;
    return super.sendAction(action, params);
  }
}
