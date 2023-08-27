import 'dart:html';

import 'package:dungeonclub/actions.dart';
import 'package:dungeonclub/iterable_extension.dart';
import 'package:dungeonclub/point_json.dart';

import '../main.dart';
import 'panels/upload.dart';
import 'session/log.dart';
import 'session/prefab.dart';
import 'session/prefab_palette.dart';
import 'session/roll_dice.dart';

Future<dynamic> handleAction(String action, Map<String, dynamic> params) async {
  switch (action) {
    case GAME_MOVABLE_CREATE:
      return user.session!.board.onMovableCreate(params);

    case GAME_MOVABLE_CREATE_ADVANCED:
      return user.session!.board.onMovableCreateAdvanced(params);

    case GAME_MOVABLE_MOVE:
      return user.session!.board.onMovablesMove(params);

    case GAME_MOVABLE_SNAP:
      return user.session!.board.onMovableSnap(params);

    case GAME_MOVABLE_UPDATE:
      return user.session!.board.onMovablesUpdate(params);

    case GAME_MOVABLE_REMOVE:
      return user.session!.board.onMovableRemove(params);

    case GAME_SCENE_PLAY:
      final session = user.session!;

      int? sceneID = params['sceneID'];

      if (sceneID != null) {
        // Prevent GM from getting teleported to the playing scene
        session.playingScene = session.scenes.find((e) => e.id == sceneID)!;
        return session.applySceneEditPlayStates();
      }

      return session.board.fromJson(params);

    case GAME_SCENE_GET:
      return user.session!.board.fromJson(params, setAsPlaying: false);

    case GAME_SCENE_UPDATE:
      var grid = params['grid'];
      if (grid != null) {
        user.session!.board.grid.fromJson(grid);
        user.session!.board.onMovablesMove(params['movables']);
        return user.session!.board.rescaleMeasurings();
      }

      return user.session!.board.changeSceneImage(params['image']);

    case GAME_SCENE_FOG_OF_WAR:
      return user.session?.board.fogOfWar.load(params['data']);

    case GAME_JOIN_REQUEST:
      return await user.account?.displayPickCharacterDialog(params['name']);

    case GAME_CONNECTION:
      return user.session?.onConnectionChange(params);

    case GAME_ROLL_DICE:
      return onDiceRollJson(params);

    case GAME_PREFAB_CREATE:
      return onPrefabCreate(params);

    case GAME_PREFAB_UPDATE:
      return onPrefabUpdate(params);

    case GAME_PREFAB_REMOVE:
      return onPrefabRemove(getPrefab(params['prefab']) as CustomPrefab);

    case GAME_MAP_CREATE:
      return user.session?.board.mapTab
          .addMap(params['map'], '', params['image'], false);

    case GAME_MAP_UPDATE:
      return user.session?.board.mapTab.onMapUpdate(params);

    case GAME_MAP_REMOVE:
      return user.session?.board.mapTab.onMapRemove(params['map']);

    case GAME_PING:
      var point = parsePoint(params)!;
      return user.session?.board.displayPing(point, params['player']);

    case GAME_CHAT:
      return onChat(params);

    case GAME_KICK:
      return user.session!.onKick(params['reason']);

    case GAME_ROLL_INITIATIVE:
      return user.session!.board.initiativeTracker.showRollerPanel();

    case GAME_ADD_INITIATIVE:
      return user.session!.board.initiativeTracker.addToInBar(params);

    case GAME_REMOVE_INITIATIVE:
      return user.session!.board.initiativeTracker.onRemoveID(params['id']);

    case GAME_CLEAR_INITIATIVE:
      return user.session!.board.initiativeTracker.outOfCombat();

    case GAME_UPDATE_INITIATIVE:
      return user.session!.board.initiativeTracker.onUpdate(params);

    case GAME_REROLL_INITIATIVE:
      return user.session!.board.initiativeTracker.reroll();

    case GAME_MUSIC_PLAYLIST:
      return user.session!.audioplayer.onNewTracklist(params);

    case GAME_MUSIC_SKIP:
      return user.session!.audioplayer.syncTracklist(params);

    case GAME_MUSIC_AMBIENCE:
      return user.session!.audioplayer.ambienceFromJson(params);

    case GAME_STORAGE_CHANGED:
      return usedStorage = params['used'];

    case MAINTENANCE:
      return user.onMaintenanceScheduled(params);
  }

  window.console.warn('Unhandled action!');
}
