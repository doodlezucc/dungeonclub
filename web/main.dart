import 'dart:html';

import 'dart/communication.dart';
import 'dart/player.dart';

Player player;

void main() {
  wsConnect();

  querySelector('h1').text = 'Eventually... it worked!!!';
  querySelector('button').onClick.listen((event) {
    Player.create('da player', 'bad password');
  });
  querySelector('button#change').onClick.listen((event) async {
    await player.changeDisplayName('zucc', 'bad password');
  });
  querySelector('button#get').onClick.listen((event) async {
    player = await Player.get('da player');
  });
  querySelector('button#save').onClick.listen((event) async {
    send('{"action":"manualSave"}');
  });
}
