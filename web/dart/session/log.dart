import 'dart:convert';
import 'dart:html';
import 'dart:math';

import 'package:dungeonclub/actions.dart';
import 'package:dungeonclub/dice_parser.dart';
import 'package:dungeonclub/session_util.dart';

import '../../main.dart';
import '../communication.dart';
import '../font_awesome.dart';
import '../formatting.dart';
import 'roll_dice.dart';
import 'session.dart';

const _historyLimit = 50;

RollCombo _command;
List<String> _history;
int _historyIndex = 0;
HtmlElement get logElem => querySelector('#log');
ButtonElement get _chatOpenButton => querySelector('#chatOpen');
HtmlElement get _miniChat => querySelector('#miniChat');

bool get mobileShowLog => !logElem.classes.contains('hidden');
set mobileShowLog(bool v) => logElem.classes.toggle('hidden', !v);

final HtmlElement _messages = querySelector('#messages');
final ButtonElement _sendButton = querySelector('#chatSend')
  ..onClick.listen((_) {
    _submitChat();
  });
HtmlElement get _rollButtonContainer => querySelector('#chatRoller');
final ButtonElement _rollButton =
    _rollButtonContainer.querySelector('#chatRoll')
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
      // Tab
      case 9:
        if (_command != null) {
          rollPublic = !rollPublic;
        }
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
  _rollButtonContainer.classes.toggle('disabled', _command == null);
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

void _performChat(int pcID, String msg) {
  final pc = user.session.characters.find((e) => e.id == pcID);
  var name = pc?.name ?? 'GM';
  var mine = pcID == user.session.charId;

  gameLog(
    (mine ? '' : '<span class="dice">$name</span> ') + msg,
    msgType: mine ? msgMine : msgOthers,
  );
}

void onChat(Map<String, dynamic> params) {
  String msg = params['msg'];
  int id = params['pc'];
  _performChat(id, msg);
}

void _saveHistory() {
  while (_history.length - 1 > _historyLimit) {
    _history.removeAt(0);
  }

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
    _chatOpenButton.onClick.listen((_) async {
      mobileShowLog = true;
      await window.onTouchStart.firstWhere((ev) => !ev.path.contains(logElem));
      mobileShowLog = false;
    });
  }
}

const msgMine = 0;
const msgOthers = 1;
const msgSystem = 2;
const msgBig = 3;

SpanElement gameLog(
  String s, {
  int msgType = msgSystem,
  bool mild = false,
  bool private = false,
}) {
  var line = SpanElement()..innerHtml = s;

  if (msgType == msgSystem) {
    line.className = 'system';
  } else if (msgType == msgBig) {
    line.className = 'big';
  } else if (msgType == msgMine) {
    line.className = 'mine';
  }

  if (mild) {
    line.classes.add('hidden');
  }
  if (private) {
    line.append(icon('eye-slash')
      ..classes.add('with-tooltip')
      ..append(SpanElement()..text = 'Private'));
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

  if (isMobile) miniLog(s);

  return line;
}

void miniLog(String s) {
  if (mobileShowLog) return;
  var mini = SpanElement()
    ..className = 'tooltip'
    ..innerHtml = s;

  _miniChat.append(mini);

  mini.animate([
    {'opacity': 1},
    {'opacity': 0.9},
  ], 1000);

  Future.delayed(Duration(seconds: 4), () {
    mini.animate([
      {'opacity': 0.9},
      {'opacity': 0},
    ], 3000);
    Future.delayed(Duration(seconds: 3), mini.remove);
  });
}

void demoLog(String s) {
  gameLog(s, mild: true, msgType: msgBig);
}

void logInviteLink(Session session) async {
  if (session.isDemo) {
    demoLog('Welcome to your very own session!');
    demoLog(
        'Explore the editor, press all the buttons and make yourself at home.');
    return;
  }

  final clipboard = window.navigator.clipboard;
  final isClipboardSupported = clipboard != null;

  final line = gameLog(
    'Hello, GM!<br>Players can join at <b>${session.inviteLink}</b>.',
    msgType: msgBig,
  )..classes.add('clickable');

  final tooltip = SpanElement()
    ..text = isClipboardSupported
        ? 'Copied to Clipboard!'
        : 'Copy this link with Ctrl+C';

  line
    ..onMouseDown.listen((_) {
      if (isClipboardSupported) {
        // Copy invite link to clipboard
        clipboard.writeText(session.inviteLink);
      }

      line.append(tooltip);
    })
    ..onMouseLeave.listen((_) async {
      await Future.delayed(Duration(milliseconds: 500));

      tooltip.remove();
    });

  if (isClipboardSupported) {
    line.classes.add('no-select');
  } else {
    // Select invite link on click
    line.onMouseUp.listen((_) async {
      await Future.delayed(Duration(milliseconds: 100));

      final inviteTextNode = line.querySelector('b');
      window.getSelection().selectAllChildren(inviteTextNode);

      await Future.any([
        window.onMouseDown.first,
        window.onKeyDown.firstWhere((ev) => ev.ctrlKey && ev.key == 'c'),
      ]);

      await Future.delayed(Duration(milliseconds: 100));
      window.getSelection().empty();
    });
  }
}
