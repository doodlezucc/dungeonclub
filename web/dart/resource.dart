import '../main.dart';
import 'communication.dart';
import 'game.dart';

class BaseResource {
  String? path;

  bool get isAsset => path?.startsWith('asset') ?? false;
  bool get isUnresolvedAsset => path?.startsWith('asset/') ?? false;
  bool get isResolvedAsset => path?.startsWith('asset:') ?? false;

  bool get isBlob => path?.startsWith('data:') ?? false;

  String? get _actualPath {
    if (path == null) return null;

    if (isUnresolvedAsset) {
      // "Unresolved" asset path, will be redirected by server
      return path;
    }

    if (isResolvedAsset) {
      final assetID = path!.substring(6);
      return 'images/assets/$assetID';
    }

    if (isBlob) {
      // Resource is base64-encoded data and doesn't need to be fetched
      return path;
    }

    throw StateError(
        'Base resource must either point to an asset or to a blob');
  }

  String get url => _actualPath == null ? '' : getFile(_actualPath!);

  BaseResource(this.path);
  BaseResource.empty() : this(null);
}

class Resource extends BaseResource {
  final Game _game;

  @override
  String? get _actualPath {
    try {
      return super._actualPath;
    } on StateError catch (_) {
      return 'database/games/${_game.id}/$path';
    }
  }

  String get url => _actualPath == null ? '' : getFile(_actualPath!);

  Resource(String? path, {Game? game})
      : _game = game ?? user.session!,
        super(path);
  Resource.empty({Game? game}) : this(null, game: game);
}
