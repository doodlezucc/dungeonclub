import 'dart:convert';
import 'dart:html';
import 'dart:math';

import 'package:dnd_interactive/actions.dart';
import 'package:dnd_interactive/dice_parser.dart';

import '../../main.dart';
import '../communication.dart';
import '../formatting.dart';
import 'roll_dice.dart';
import 'session.dart';

RollCombo _command;
List<String> _history;
int _historyIndex = 0;
HtmlElement get logElem => querySelector('#log');

bool get mobileShowLog => !logElem.classes.contains('hidden');
set mobileShowLog(bool v) => logElem.classes.toggle('hidden', !v);

final HtmlElement _messages = querySelector('#messages');
final ButtonElement _sendButton = querySelector('#chatSend')
  ..onClick.listen((_) {
    _submitChat();
  });
final ButtonElement _rollButton = querySelector('#chatRoll')
  ..onClick.listen((_) {
    _submitChat(roll: true);
  });
final TextAreaElement _chat = querySelector('#chat textarea')
  ..onKeyDown.listen((ev) {
    switch (ev.keyCode) {
      // Enter
      case 13:
        _submitChat(roll: _command != null);
        return ev.preventDefault();
      // Arrow Up
      case 38:
        _navigateHistory(-1);
        return ev.preventDefault();
      // Arrow Down
      case 40:
        _navigateHistory(1);
        return ev.preventDefault();
      default:
    }
  })
  ..onInput.listen((_) => _updateSendButton());

void _navigateHistory(int step) {
  var lastIndex = _history.length - 1;
  if (_historyIndex == lastIndex) {
    _history[lastIndex] = _chat.value;
  }
  _historyIndex = min(max(_historyIndex + step, 0), _history.length - 1);
  _chat.value = _history[_historyIndex];
  _updateSendButton();
}

void _cleanupHistory() {
  var unique = <String>{};
  for (var i = _history.length - 1; i >= 0; i--) {
    var msg = _history[i];

    if (!unique.add(msg)) {
      _history.removeAt(i);
    }
  }

  _chat.value = '';
  _historyIndex = _history.length - 1;
  _navigateHistory(0);
}

void _updateSendButton() {
  var msg = _chat.value.trim();
  _sendButton.disabled = msg.isEmpty;

  if (DiceParser.isCommand(msg)) {
    _command = DiceParser.parse(msg);
    if (_command != null) {
      var cmdHtml = wrapAround(_command.toCommandString(), 'b');
      _rollButton.querySelector('span').innerHtml = 'Roll $cmdHtml';
    }
  } else {
    _command = null;
  }
  _rollButton.disabled = _command == null;
}

void _submitChat({bool roll = false}) {
  var msg = _chat.value.trimRight();
  if (msg.isNotEmpty) {
    var pc = user.session.charId;

    if (roll) {
      sendRollDice(_command);
    } else {
      _performChat(pc, msg);
      socket.sendAction(GAME_CHAT, {'msg': msg, 'pc': pc});
    }

    if (_historyIndex < _history.length - 1) {
      _history.removeLast();
    }

    _history.add(msg);
    _history.add('');
    _cleanupHistory();
    _saveHistory();
  }
  if (isMobile) {
    _chat.focus();
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

void _saveHistory() {
  window.localStorage['chat'] =
      jsonEncode(_history.sublist(0, _history.length - 1));
}

void initGameLog() {
  _chat.classes.add('ready');
  _sendButton.classes.add('ready');

  var jsonList = jsonDecode(window.localStorage['chat'] ?? '[]');
  _history = List<String>.from([...jsonList, '']);
  _cleanupHistory();

  if (isMobile) {
    _chat.rows = 1;
    querySelector('#chatOpen').onClick.listen((_) async {
      mobileShowLog = true;
      await window.onTouchStart.firstWhere((ev) => !ev.path.contains(logElem));
      mobileShowLog = false;
    });
  }
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
