import 'dart:html';

import 'package:dnd_interactive/actions.dart';

import '../main.dart';
import 'session/log.dart';
import 'session/prefab_palette.dart';
import 'session/roll_dice.dart';

Future<dynamic> handleAction(String action, Map<String, dynamic> params) async {
  switch (action) {
    case GAME_MOVABLE_CREATE:
      return user.session.board.onMovableCreate(params);

    case GAME_MOVABLE_MOVE:
      return user.session.board.onMovableMove(params);

    case GAME_MOVABLE_UPDATE:
      return user.session.board.onMovableUpdate(params);

    case GAME_MOVABLE_REMOVE:
      return user.session.board.onMovableRemove(params);

    case GAME_SCENE_PLAY:
      int id = params['id'];
      return user.session?.board?.fromJson(id, params);

    case GAME_SCENE_UPDATE:
      var grid = params['grid'];
      if (grid != null) {
        user.session?.board?.grid?.fromJson(grid);
        user.session?.board?.onAllMovablesMove(params['movables']);
      }
      return user.session?.board?.onImgChange();

    case GAME_JOIN_REQUEST:
      return await user.account?.displayPickCharacterDialog('joe');

    case GAME_CONNECTION:
      return _onConnectionChange(params);

    case GAME_ROLL_DICE:
      return onDiceRoll(params);

    case GAME_PREFAB_CREATE:
      return onPrefabCreate(params);

    case GAME_PREFAB_UPDATE:
      return onPrefabUpdate(params);
  }

  window.console.warn('Unhandled action!');
}

void _onConnectionChange(Map<String, dynamic> params) {
  bool join = params['join'];
  int pc = params['pc'];

  var name = pc != null ? user.session.characters[pc].name : 'GM';

  if (join) {
    gameLog('$name joined the game.');
  } else {
    gameLog('$name left the game.');
  }
}
