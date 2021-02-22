import 'dart:html';

import '../main.dart';
import 'server_actions.dart';

Future<dynamic> handleAction(String action, Map<String, dynamic> params) async {
  print('Action $action incoming');

  switch (action) {
    case GAME_MOVABLE_CREATE:
      return user.session.board.onMovableCreate(params);

    case GAME_MOVABLE_MOVE:
      return user.session.board.onMovableMove(params);

    case GAME_JOIN_REQUEST:
      return await user.account?.displayJoinRequestDialog('joe');
  }

  window.console.warn('Unhandled action!');
}
