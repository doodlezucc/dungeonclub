import '../main.dart';
import 'communication.dart';
import 'game.dart';

class Resource {
  final Game _game;
  String path;

  String get _actualPath {
    if (path == null) return null;

    if (path.startsWith('assets/')) {
      return 'images/$path';
    }

    return 'database/games/${_game.id}/$path';
  }

  String get url =>
      _actualPath == null ? '' : getFile(_actualPath, cacheBreak: false);

  Resource(this.path, {Game game}) : _game = game ?? user.session;
  Resource.empty({Game game}) : this(null, game: game);
}
