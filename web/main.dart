import 'dart:html';

import 'dart/communication.dart';
import 'dart/player.dart';

LocalPlayer player;

void main() {
  wsConnect();

  querySelector('h1').text = 'Eventually... it worked!!!';
  querySelector('button#create').onClick.listen((event) async {
    player = await Player.create('da player', 'bad password');
  });
  querySelector('button#get').onClick.listen((event) async {
    await Player.get('da player');
  });
  querySelector('button#login').onClick.listen((event) async {
    player = await LocalPlayer.login('da player', 'bad password');
  });
  querySelector('button#change').onClick.listen((event) async {
    await player.changeDisplayName('zucc', 'bad password');
  });
  querySelector('button#save').onClick.listen((event) async {
    send('{"action":"manualSave"}');
  });
}
