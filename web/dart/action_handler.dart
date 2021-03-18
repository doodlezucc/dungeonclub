import 'dart:html';

import 'package:dnd_interactive/actions.dart';

import '../main.dart';
import 'session/roll_dice.dart';

Future<dynamic> handleAction(String action, Map<String, dynamic> params) async {
  switch (action) {
    case GAME_MOVABLE_CREATE:
      return user.session.board.onMovableCreate(params);

    case GAME_MOVABLE_MOVE:
      return user.session.board.onMovableMove(params);

    case GAME_SCENE_UPDATE:
      var grid = params['grid'];
      if (grid != null) {
        return user.session?.board?.grid?.fromJson(grid);
      }
      return user.session?.board?.onImgChange();

    case GAME_SCENE_PLAY:
      int id = params['id'];
      return user.session?.board?.fromJson(id, params);

    case GAME_JOIN_REQUEST:
      return await user.account?.displayPickCharacterDialog('joe');

    case GAME_CONNECTION:
      return _onConnectionChange(params);

    case GAME_ROLL_DICE:
      return onDiceRoll(params);
  }

  window.console.warn('Unhandled action!');
}

void _onConnectionChange(Map<String, dynamic> params) {
  bool join = params['join'];
  int pc = params['pc'];

  var name = pc != null ? user.session.characters[pc].name : 'GM';

  if (join) {
    print('$name joined the game');
  } else {
    print('$name left the game');
  }
}
