import '../main.dart';
import 'communication.dart';
import 'game.dart';

class Resource {
  final Game _game;
  String path;

  bool get isAsset => path?.startsWith('asset') ?? false;
  bool get isUnresolvedAsset => path?.startsWith('asset/') ?? false;
  bool get isResolvedAsset => path?.startsWith('asset:') ?? false;

  bool get isBlob => path?.startsWith('data:') ?? false;

  String get _actualPath {
    if (path == null) return null;

    if (isUnresolvedAsset) {
      // "Unresolved" asset path, will be redirected by server
      return path;
    }

    if (isResolvedAsset) {
      final assetID = path.substring(6);
      return 'images/assets/$assetID';
    }

    if (isBlob) {
      // Resource is base64-encoded data and doesn't need to be fetched
      return path;
    }

    return 'database/games/${_game.id}/$path';
  }

  String get url => _actualPath == null ? '' : getFile(_actualPath);

  Resource(this.path, {Game game}) : _game = game ?? user.session;
  Resource.empty({Game game}) : this(null, game: game);
}
