import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dungeonclub/comms.dart';
import 'limits.dart';
import 'package:path/path.dart' as path;
import 'package:random_string/random_string.dart';

import 'asset_provider.dart';
import 'data.dart';

const ASSET_PREFIX = 'asset';
const ASSET_RESOLVED_PREFIX = '$ASSET_PREFIX:';
const ASSET_UNRESOLVED_PREFIX = '$ASSET_PREFIX/';

class ControlledResource {
  final Game game;
  final String fileExtension;
  ResourceFile? _file;

  ResourceFile? get file => _file;
  String? get filePath => _file?.path.replaceAll(r'\', '/');

  ControlledResource(
    this.game,
    ResourceFile file, {
    this.fileExtension = GameFile.defaultFileExension,
  }) : _file = file;

  ControlledResource.empty(
    this.game, {
    this.fileExtension = GameFile.defaultFileExension,
  });

  ControlledResource.path(
    Game game,
    String filePath, {
    String fileExtension = GameFile.defaultFileExension,
  }) : this(game, ResourceFile.parse(game, filePath),
            fileExtension: fileExtension);

  static Future<ControlledResource> withData(Game game, String data) async {
    final resource = ControlledResource.empty(game);
    await resource.replaceWithData(data);
    return resource;
  }

  /// Creates a new file reference and optionally deletes the previous one.
  Future<GameFile> replaceWithEmptyFile({bool deletePrevious = true}) async {
    final newFile = await GameFile.make(game, fileExtension: fileExtension);
    await newFile.reference.create(recursive: true);

    replaceWithFile(
      newFile,
      deletePrevious: deletePrevious,
      registerInGameStorage: false,
    );

    return newFile;
  }

  /// Replaces the current file reference with a new one.
  void replaceWithFile(
    ResourceFile file, {
    bool deletePrevious = true,
    bool registerInGameStorage = true,
  }) {
    if (file == _file) return;

    if (deletePrevious) {
      _deleteObsoleteFile(_file, notifyGM: (file is! GameFile));
    }

    _file = file;

    if (registerInGameStorage && file is GameFile) {
      game.onResourceAdd(file.reference);
    }
  }

  Future<ResourceFile?> replaceWithData(String data) async {
    final bytesAvailable = mediaBytesPerCampaign - game.usedDiskSpace;

    if (data.startsWith(ASSET_PREFIX)) {
      // [data] is a path to an asset
      final assetFile = await AssetFile.parse(data);
      replaceWithFile(assetFile);
    } else {
      final byteData = base64Decode(data);
      final uploadSize = byteData.lengthInBytes;

      if (uploadSize > bytesAvailable) {
        throw UploadError(
            uploadSize, game.usedDiskSpace, mediaBytesPerCampaign);
      }

      final destination = await replaceWithEmptyFile();
      await destination.reference.writeAsBytes(byteData);

      game.onResourceAddBytes(uploadSize);
    }

    return _file;
  }

  Map<String, dynamic>? toJsonResponse() => _file?.toJsonResponse();

  /// Deletes the resource's file reference.
  Future<void> delete() => _deleteObsoleteFile(_file);

  /// Deletes the resource's file reference (unawaited).
  void deleteInBackground() => delete();

  /// Deletes a game file which is no longer used.
  Future<void> _deleteObsoleteFile(ResourceFile? file,
      {bool notifyGM = true}) async {
    if (file != null && file is GameFile) {
      if (await file.reference.exists()) {
        await game.onResourceRemove(file.reference, notifyGM: notifyGM);
        await file.reference.delete();
      }
    }
  }
}

abstract class ResourceFile {
  final String path;
  final File reference;

  ResourceFile(this.path, this.reference);

  static ResourceFile parse(Game game, String filePath) {
    if (filePath.startsWith(ASSET_PREFIX)) {
      return AssetFile.fromResolved(filePath);
    }
    return GameFile(game, filePath);
  }

  Map<String, dynamic> toJsonResponse() => {'image': path};
}

class AssetFile extends ResourceFile {
  AssetFile(String path)
      : super('$ASSET_RESOLVED_PREFIX$path', File('web/images/assets/$path'));

  AssetFile.fromResolved(String filePath)
      : this(filePath.substring(ASSET_RESOLVED_PREFIX.length));

  static AssetFile tryAsSceneAsset(String path) {
    final assetFile = AssetFile(path);

    try {
      return SceneAssetFile.parseTiles(assetFile);
    } catch (_) {
      return AssetFile(path);
    }
  }

  static Future<AssetFile> parse(String filePath) async {
    if (filePath.startsWith(ASSET_UNRESOLVED_PREFIX)) {
      final path = await AssetProviderService.resolveIndexedAsset(filePath);

      return tryAsSceneAsset(path);
    }

    return AssetFile.fromResolved(filePath);
  }
}

class SceneAssetFile implements AssetFile {
  static final _tilesRegex = RegExp(r'(\d+)x\d');
  final AssetFile _asset;
  final int recommendedTiles;

  SceneAssetFile(AssetFile asset, this.recommendedTiles) : _asset = asset;
  SceneAssetFile.parseTiles(AssetFile asset)
      : this(asset, _parseHorizontalTiles(asset.path));

  // Grid size is embedded in the file name (e.g. "44x32")
  static int _parseHorizontalTiles(String fileName) {
    final tilesString = _tilesRegex.firstMatch(fileName)![1];
    return int.parse(tilesString!);
  }

  @override
  String get path => _asset.path;

  @override
  File get reference => _asset.reference;

  @override
  Map<String, dynamic> toJsonResponse() => {
        ..._asset.toJsonResponse(),
        'tiles': recommendedTiles,
      };
}

class GameFile extends ResourceFile {
  static const defaultFileExension = 'jpg';
  static const fileNameCharacters = 5;

  final Game game;

  GameFile(this.game, String fileName)
      : super(
          fileName,
          File(path.join(game.resources.path, fileName)),
        );

  GameFile.fromFile(this.game, File file)
      : super(path.basename(file.path), file);

  /// Returns a new (= non-existent) file located in the `parent` directory
  /// with a given `fileExtension`.
  static Future<GameFile> make(
    Game game, {
    String fileExtension = defaultFileExension,
  }) async {
    File file;
    do {
      final basename = _randomBasename();
      final fileName = '$basename.$fileExtension';

      final filePath = path.join(game.resources.path, fileName);

      file = File(filePath);
    } while (await file.exists());

    return GameFile.fromFile(game, file);
  }

  static String _randomBasename() {
    return randomAlphaNumeric(fileNameCharacters);
  }
}

class UploadError extends ResponseError {
  final int bytesUpload;
  final int bytesUsed;
  final int bytesMaximum;

  UploadError(this.bytesUpload, this.bytesUsed, this.bytesMaximum)
      : super(
          'Limit of $bytesMaximum bytes surpassed by $bytesUpload bytes',
          {
            'bytesUpload': bytesUpload,
            'bytesUsed': bytesUsed,
            'bytesMaximum': bytesMaximum,
          },
        );
}
