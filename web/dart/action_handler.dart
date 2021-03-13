import 'dart:html';

import 'package:dnd_interactive/actions.dart';

import '../main.dart';

Future<dynamic> handleAction(String action, Map<String, dynamic> params) async {
  print('Action $action incoming');

  switch (action) {
    case GAME_MOVABLE_CREATE:
      return user.session.board.onMovableCreate(params);

    case GAME_MOVABLE_MOVE:
      return user.session.board.onMovableMove(params);

    case GAME_SCENE_UPDATE:
      return user.session?.board?.onImgChange();

    case GAME_JOIN_REQUEST:
      return await user.account?.displayPickCharacterDialog('joe');

    case GAME_CONNECTION:
      return _onConnectionChange(params);
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
