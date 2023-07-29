import 'dart:convert';
import 'dart:html';

import 'package:dungeonclub/limits.dart';

import '../main.dart';
import 'changelog.dart';
import 'html_helpers.dart';
import 'game.dart';
import 'icon_wall.dart';
import 'notif.dart';
import 'panels/code_panel.dart';
import 'panels/edit_game.dart' as edit_game;
import 'panels/join_session.dart' as join_session;
import 'section_page.dart';

final HtmlElement _gamesContainer = queryDom('#gamesContainer');
final ButtonElement _createGameButton = queryDom('#create');
final HtmlElement _loginTab = queryDom('#loginTab');
final ButtonElement _logout = queryDom('#logOut')
  ..onClick.listen((_) {
    window.localStorage.remove('token');
    window.location.reload();
  });
HtmlElement get _enterDemoButton => queryDom('#enterDemo');

final iconWall = IconWall(queryDom('#iconWall'));

Future<void> init() {
  iconWall.spawnParticles();
  changelog.fetch();

  _enterDemoButton.onClick.listen((_) => user.joinDemo());

  _createGameButton.onClick.listen((event) async {
    if (!user.registered) {
      return HtmlNotification('No permissions to create a new game!').display();
    }

    if (_gamesContainer.children.length > campaignsPerAccount) {
      return HtmlNotification(
              'Limit of $campaignsPerAccount campaigns reached.')
          .display();
    }

    var game = await user.account.createNewGame();

    if (game != null) _addEnteredGame(game);
  });

  _displayLocalEnteredGames();

  showPage('home');
  return _initLogInTab();
}

Future<bool> _initLogInTab() async {
  InputElement loginEmail = queryDom('#loginEmail');
  InputElement loginPassword = queryDom('#loginPassword');
  ButtonElement loginButton = queryDom('button#login');
  HtmlElement loginError = queryDom('#loginError');
  AnchorElement resetPassword = queryDom('#resetPassword');
  CheckboxInputElement rememberMe = queryDom('#rememberMe input');
  rememberMe.checked = window.localStorage['rememberMe'] == 'true';

  resetPassword.onClick.listen((_) => resetPanel.display());

  loginButton.onClick.listen((_) async {
    loginButton.disabled = true;
    loginError.text = null;

    var doRemember = rememberMe.checked;
    if (!doRemember) window.localStorage.remove('token');

    window.localStorage['rememberMe'] = '$doRemember';

    var loggedIn = await user.login(
      loginEmail.value,
      loginPassword.value,
      rememberMe: rememberMe.checked,
    );

    if (!loggedIn) {
      loginError.text = 'Failed to log in.';
      loginButton.disabled = false;
    } else {
      loginError.text = null;
    }
  });

  var token = window.localStorage['token'];
  if (token != null) {
    if (await user.loginToken(token)) return true;
  }
  _loginTab.classes.remove('hidden');
  return false;
}

void onLogin() {
  queryDom('#loginText').style.animationPlayState = 'running';
  _loginTab.classes.add('hidden');
  _logout.classes.remove('hidden');
  _showGamesContainer();
  _displayAccountEnteredGames();
  querySelectorAll('.acc-enable').forEach((element) {
    (element as ButtonElement).disabled = false;
  });
}

Future<void> _displayAccountEnteredGames() async {
  for (var g in user.account.games) {
    // Remove saved game if you're actually the owner
    var saved = _gamesContainer.queryDom('[id="${g.id}"]');
    if (saved != null) saved.remove();

    _addEnteredGame(g);
  }
}

Future<void> _displayLocalEnteredGames() async {
  var idNames = Map<String, String>.from(
      jsonDecode(window.localStorage['joined'] ?? '{}'));

  for (var g in idNames.entries) {
    _addEnteredGame(Game(g.key, g.value, false));
  }
}

void _showGamesContainer() {
  queryDom('#savedGames').style.display = 'flex';
}

void _addEnteredGame(Game game) {
  _showGamesContainer();
  HtmlElement nameEl;
  HtmlElement topRow;
  var e = DivElement()
    ..className = 'game'
    ..setAttribute('id', game.id)
    ..append(topRow = SpanElement()
      ..append(nameEl = HeadingElement.h3()..text = game.name))
    ..append(ButtonElement()
      ..text = game.owned ? 'Host Session' : 'Join Session'
      ..onClick.listen((event) {
        if (game.owned) {
          user.joinSession(game.id);
        } else {
          join_session.display(game.id);
        }
      }));

  if (game.owned) {
    topRow.append(iconButton('cog', className: 'with-tooltip')
      ..onClick.listen((_) => edit_game.display(game, nameEl, e))
      ..append(SpanElement()..text = 'Settings'));
  } else {
    topRow.append(iconButton('times', className: 'with-tooltip')
      ..onClick.listen((_) {
        e.remove();
        _unsaveGame(game.id);
      })
      ..append(SpanElement()..text = 'Unsave Campaign'));
  }

  _gamesContainer.insertBefore(e, _createGameButton);
}

void _unsaveGame(String id) {
  var idNames = Map<String, String>.from(
      jsonDecode(window.localStorage['joined'] ?? '{}'));
  idNames.remove(id);
  window.localStorage['joined'] = jsonEncode(idNames);
}
