import 'dart:async';
import 'dart:html';

import 'package:dungeonclub/actions.dart';
import 'package:dungeonclub/comms.dart';
import 'package:dungeonclub/environment.dart';
import 'package:path/path.dart';
import 'package:web_whiteboard/communication/web_socket.dart';

import '../main.dart';
import 'action_handler.dart' as handler;
import 'html_helpers.dart';
import 'panels/dialog.dart';
import 'session/measuring.dart';

final String _serverAddress = _getServerAddress();

final socket = FrontSocket();

bool get isDebugging {
  final webPort = window.location.port;
  return !Environment.isCompiled && webPort == '8080';
}

String _getServerAddress() {
  final address = window.location.origin;

  if (isDebugging) {
    // Replace address port 8080 with default server port 7070
    return address.substring(0, address.length - 4) + '7070';
  }

  return address;
}

String getFile(String path) {
  path = Uri.encodeFull(path);
  return join(_serverAddress, path);
}

const demoActions = [
  FEEDBACK,
  GAME_MUSIC_PLAYLIST,
];

class FrontSocket extends Socket {
  WebSocket? _webSocket;
  final _waitForOpen = Completer();
  Timer? _retryTimer;
  ConstantDialog? _errorDialog;
  bool _manualClose = false;

  Future<void> _requireConnection() async {
    if (_webSocket == null) {
      connect();
    }
    return _waitForOpen.future;
  }

  void connect({bool goHome = true}) {
    _retryTimer?.cancel();
    _webSocket = WebSocket(getFile('ws').replaceFirst('http', 'ws'))
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

  void close() {
    _manualClose = true;
    _webSocket?.close();
  }

  void _handleConnectionClose() async {
    if (_manualClose) return;

    _errorDialog ??= ConstantDialog('Connection Error')
      ..addParagraph('Your connection to the server was closed unexpectedly.')
      ..addParagraph('Reconnecting...')
      ..append(icon('spinner')..classes.add('spinner'))
      ..display();

    _retryTimer = Timer(Duration(seconds: 1), () => connect(goHome: false));
  }

  void _handleConnectionError() async {
    if (_manualClose) return;

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

  bool canSend(String action) {
    if (user.isInDemo && !demoActions.contains(action)) {
      return false;
    }
    return true;
  }

  @override
  Stream get messageStream => _webSocket!.onMessage.map((event) => event.data);

  @override
  Future<void> send(data) async {
    if (user.isInDemo && data is! String) return;

    await _requireConnection();
    _webSocket!.send(data);
  }

  @override
  Future<dynamic> request(String action, [Map<String, dynamic>? params]) async {
    if (!canSend(action)) return null;

    await _requireConnection();
    return super.request(action, params);
  }

  @override
  Future<void> sendAction(String action, [Map<String, dynamic>? params]) async {
    if (!canSend(action)) return;

    await _requireConnection();
    return super.sendAction(action, params);
  }

  @override
  Future handleAction(
    String action, [
    Map<String, dynamic> params = const {},
  ]) =>
      handler.handleAction(action, params);

  @override
  void handleBinary(data) async {
    if (data is Blob) {
      var bytes = await blobToBytes(data);
      var port = bytes.first;

      if (port == measuringPort) {
        handleMeasuringEvent(bytes);
      } else if (port != 99) {
        user.session?.board.mapTab.handleEvent(bytes);
      }
    }
  }
}
