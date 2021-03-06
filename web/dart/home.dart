import 'dart:html';

import '../main.dart';
import 'font_awesome.dart';
import 'game.dart';
import 'panels/edit_game.dart' as edit_game;

final HtmlElement _gamesContainer = querySelector('#gamesContainer');
final ButtonElement _createGameButton = querySelector('#create');

void init() {
  if (user.registered) {
    _displayEnteredGames();
  }

  _createGameButton.onClick.listen((event) async {
    if (!user.registered) return print('No permissions to create a new game!');
    var game = await user.account.createNewGame('Cool Campaign');
    await edit_game.display(game);
  });
}

Future<void> _displayEnteredGames() async {
  for (var g in user.account.games) {
    _addEnteredGame(g);
  }
}

void _addEnteredGame(Game game) {
  HtmlElement topRow;
  var e = DivElement()
    ..className = 'game'
    ..append(
        topRow = SpanElement()..append(HeadingElement.h3()..text = game.name))
    ..append(ButtonElement()
      ..text = 'Join session'
      ..onClick.listen((event) {
        user.joinSession(game.id);
      }));

  if (game.owned) {
    topRow.append(iconButton('cog')
      ..onClick.listen((event) {
        edit_game.display(game);
      }));
  }

  _gamesContainer.insertBefore(e, _createGameButton);
}
