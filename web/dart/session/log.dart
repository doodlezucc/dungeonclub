import 'dart:html';

import 'package:dnd_interactive/actions.dart';

import '../../main.dart';
import '../communication.dart';
import 'session.dart';

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
  var name = pcId == null ? 'GM' : user.session.characters[pcId].name;

  gameLog('<span class="dice">$name</span> $msg');
}

void onChat(Map<String, dynamic> params) {
  String msg = params['msg'];
  int id = params['pc'];
  _performChat(id, msg);
}

void initGameLog() {
  _chat.classes.add('ready');
  _sendButton.classes.add('ready');
}

SpanElement gameLog(String s, {bool mine = false, bool mild = false}) {
  var line = SpanElement()..innerHtml = s;
  if (mine) {
    line.className = 'mine';
  }
  if (mild) {
    line.classes.add('hidden');
  }

  _messages.append(line);
  _messages.scrollTop = _messages.scrollHeight;

  if (!mild) {
    Future.delayed(Duration(seconds: 8), () {
      line.animate([
        {'opacity': 1},
        {'opacity': 0.6},
      ], 2000);
      line.classes.add('hidden');
    });
  }

  return line;
}

void demoLog(String s) {
  gameLog(s, mild: true);
}

void logInviteLink(Session session) async {
  if (session.isDemo) {
    demoLog('Welcome to your very own session!');
    demoLog(
        'Explore the editor, press all the buttons and make yourself at home.');
    return;
  }

  var tooltip = SpanElement()..text = 'Copied to Clipboard!';

  var line = gameLog('''Hello, GM!<br>Players can join at
    <b>${session.inviteLink}</b>.''')..classes.add('clickable');

  line
    ..onMouseDown.listen((_) {
      window.navigator.clipboard.writeText(session.inviteLink);
      line.append(tooltip);
    })
    ..onMouseLeave.listen((_) async {
      await Future.delayed(Duration(milliseconds: 500));
      tooltip.remove();
    });
}
