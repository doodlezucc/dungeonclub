import 'dart:html';

import '../main.dart';
import 'font_awesome.dart';
import 'game.dart';
import 'panels/dialog.dart';
import 'panels/edit_game.dart' as edit_game;

final HtmlElement _gamesContainer = querySelector('#gamesContainer');
final ButtonElement _createGameButton = querySelector('#create');

void init() {
  if (user.registered) {
    _displayEnteredGames();
    querySelectorAll('.acc-enable').forEach((element) {
      (element as ButtonElement).disabled = false;
    });
  }

  _createGameButton.onClick.listen((event) async {
    if (!user.registered) return print('No permissions to create a new game!');

    var name = await Dialog<String>(
      'New Campaign',
      okText: 'Create',
      onClose: () => null,
    ).withInput(placeholder: 'Campaign name...').display();

    if (name == null) return;

    var game = await user.account.createNewGame(name);
    _addEnteredGame(game, instantEdit: true);
  });
}

Future<void> _displayEnteredGames() async {
  for (var g in user.account.games) {
    _addEnteredGame(g);
  }
}

void _addEnteredGame(Game game, {bool instantEdit = false}) {
  HtmlElement nameEl;
  HtmlElement topRow;
  var e = DivElement()
    ..className = 'game'
    ..append(topRow = SpanElement()
      ..append(nameEl = HeadingElement.h3()..text = game.name))
    ..append(ButtonElement()
      ..text = 'Join session'
      ..onClick.listen((event) {
        user.joinSession(game.id);
      }));

  var displayEdit = () {
    edit_game.display(game, nameEl, e);
  };

  if (game.owned) {
    topRow.append(iconButton('cog')..onClick.listen((_) => displayEdit()));
  }

  _gamesContainer.insertBefore(e, _createGameButton);

  if (instantEdit) displayEdit();
}
