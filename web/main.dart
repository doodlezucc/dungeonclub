import 'dart:html';

import 'dart/player.dart';

Player player;

void main() {
  querySelector('h1').text = 'Eventually... it worked!!!';
  querySelector('button').onClick.listen((event) {
    Player.create('da player', 'bad password');
  });
  querySelector('button#change').onClick.listen((event) async {
    await player.changeDisplayName('fwd', 'bad password');
  });
  querySelector('button#get').onClick.listen((event) async {
    player = await Player.get('da player');
  });

  wsConnect();
}

void wsConnect() {
  print('connecting...');
  var webSocket = WebSocket('ws://localhost:7070/ws');
  webSocket.onOpen.listen((e) => print('OPEN'));
  webSocket.onClose.listen((e) => print('CLOSE'));
  webSocket.onError.listen((e) => print(e));
  webSocket.onMessage.listen((e) => print('MSG: ' + e.data));
}
