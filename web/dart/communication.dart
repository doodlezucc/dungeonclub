import 'dart:async';
import 'dart:html';

import 'package:dnd_interactive/comms.dart';
import 'package:path/path.dart';
import 'package:web_whiteboard/communication/web_socket.dart';

import '../main.dart';
import 'action_handler.dart' as handler;
import 'font_awesome.dart';
import 'panels/dialog.dart';
import 'session/measuring.dart';

final socket = FrontSocket();

final bool isOnLocalHost = window.location.hostname == 'localhost';
final String _serverAddress = isOnLocalHost
    ? 'http://localhost:7070'
    : join(window.location.origin, 'dnd');

String getFile(String path, {bool cacheBreak = true}) {
  var out = join(_serverAddress, path);
  if (!cacheBreak) return out;

  return '$out?${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
}

String getGameFile(String path, {String gameId, bool cacheBreak = true}) {
  gameId = gameId ?? user?.session?.id;
  return getFile('database/games/$gameId/$path', cacheBreak: cacheBreak);
}

class FrontSocket extends Socket {
  WebSocket _webSocket;
  final _waitForOpen = Completer();
  Timer _retryTimer;
  ConstantDialog _errorDialog;

  Future<void> _requireConnection() async {
    if (_webSocket == null) {
      connect();
    }
    return _waitForOpen.future;
  }

  void connect({bool goHome = true}) {
    _retryTimer?.cancel();
    _webSocket =
        WebSocket(getFile('ws', cacheBreak: false).replaceFirst('http', 'ws'))
          ..onOpen.listen((e) {
            if (_errorDialog != null) {
              window.location.href = goHome ? homeUrl : window.location.href;
            } else {
              _waitForOpen.complete();
            }
          })
          ..onClose.listen((e) => _handleConnectionClose())
          ..onError.listen((e) => _handleConnectionError());

    listen();
  }

  void close() => _webSocket.close();

  void _handleConnectionClose() async {
    _errorDialog ??= ConstantDialog('Connection Error')
      ..addParagraph('Your connection to the server was closed unexpectedly.')
      ..addParagraph('Reconnecting...')
      ..append(icon('spinner')..classes.add('spinner'))
      ..display();

    _retryTimer = Timer(Duration(seconds: 1), () => connect(goHome: false));
  }

  void _handleConnectionError() async {
    document.title = 'Reconnecting...';
    _errorDialog ??= ConstantDialog('Connection Error')
      ..addParagraph('''The $appName server seems to be offline.
        It's probably under maintenance or loading a cool new feature.
        You may go get a coffee or some bread if you feel like it.''')
      ..addParagraph('''The server should be back up
        in a few minutes or seconds, even.
        As soon as possible, you will be automatically reconnected!''')
      ..append(icon('spinner')..classes.add('spinner'))
      ..display();

    _retryTimer = Timer(Duration(seconds: 10), () => connect());
  }

  @override
  Stream get messageStream => _webSocket.onMessage.map((event) => event.data);

  @override
  Future<void> send(data) async {
    await _requireConnection();
    _webSocket.send(data);
  }

  @override
  Future<dynamic> request(String action, [Map<String, dynamic> params]) async {
    await _requireConnection();
    return super.request(action, params);
  }

  @override
  Future<void> sendAction(String action, [Map<String, dynamic> params]) async {
    await _requireConnection();
    return super.sendAction(action, params);
  }

  @override
  Future handleAction(String action, [Map<String, dynamic> params]) =>
      handler.handleAction(action, params);

  @override
  void handleBinary(data) async {
    if (data is Blob) {
      var bytes = await blobToBytes(data);
      var port = bytes.first;

      if (port == measuringPort) {
        handleMeasuringEvent(bytes);
      } else if (port != 99) {
        user.session?.board?.mapTab?.handleEvent(bytes);
      }
    }
  }
}
