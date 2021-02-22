import 'package:web_socket_channel/web_socket_channel.dart';

import '../web/comms.dart';

class BackSocket extends Socket {
  final WebSocketChannel ws;

  BackSocket(this.ws);

  @override
  Stream get messageStream => ws.stream;

  @override
  Future<void> send(data) async => ws.sink.add(data);
}
