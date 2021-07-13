import 'dart:html';

import 'package:dnd_interactive/actions.dart';

import '../../main.dart';
import '../communication.dart';

final HtmlElement _messages = querySelector('#messages');
final ButtonElement _sendButton = querySelector('#chat button')
  ..onClick.listen((_) {
    _submitChat();
  });
final TextAreaElement _chat = querySelector('#chat textarea')
  ..onKeyDown.listen((ev) {
    if (ev.keyCode == 13) {
      _submitChat();
      ev.preventDefault();
    }
  })
  ..onInput.listen((_) => _updateSendButton());

void _updateSendButton() {
  _sendButton.disabled = _chat.value.isEmpty;
}

void _submitChat() {
  var msg = _chat.value.trimRight();
  if (msg.isNotEmpty) {
    _chat.value = '';
    _updateSendButton();
    var pc = user.session.charId;
    _performChat(pc, msg);
    socket.sendAction(GAME_CHAT, {'msg': msg, 'pc': pc});
  }
}

void _performChat(int pcId, String msg) {
  var name = pcId == null ? 'DM' : user.session.characters[pcId].name;

  gameLog('<span class="dice">$name</span> $msg');
}

void onChat(Map<String, dynamic> params) {
  String msg = params['msg'];
  int id = params['pc'];
  _performChat(id, msg);
}

void gameLog(String s, {bool mine = false}) async {
  // Initialize chat
  _chat.classes.add('ready');
  _sendButton.classes.add('ready');

  var line = SpanElement()..innerHtml = s;
  if (mine) {
    line.className = 'mine';
  }

  _messages.append(line);
  _messages.scrollTop = _messages.scrollHeight;

  await Future.delayed(Duration(seconds: 8));
  line.animate([
    {'opacity': 1},
    {'opacity': 0.6},
  ], 2000);
  line.classes.add('hidden');
}
