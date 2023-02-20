import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:random_string/random_string.dart';

import 'data.dart';

class ControlledResource {
  static const fileNameCharacters = 5;
  static const defaultFileExension = 'jpg';

  final Game game;
  final String fileExtension;
  ResourceFile _file;

  Directory get parentDirectory => game.resources;
  String get filePath => _file?.path;
  File get referencedFile => _file?.reference;

  ControlledResource(
    this.game,
    ResourceFile file, {
    this.fileExtension = defaultFileExension,
  }) : _file = file;

  ControlledResource.empty(
    this.game, {
    this.fileExtension = defaultFileExension,
  });

  ControlledResource.path(
    Game game,
    String filePath, {
    String fileExtension = defaultFileExension,
  }) : this(
          game,
          ResourceFile.parse(game, filePath),
          fileExtension: fileExtension,
        );

  /// Creates a new file reference and optionally deletes the previous one.
  Future<File> replace({bool deletePrevious = true}) async {
    final newFile = await newRandomFileName(parentDirectory, fileExtension);
    await newFile.create(recursive: true);

    replaceWithFile(
      GameFile.fromFile(game, newFile),
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
      _deleteObsoleteFile(referencedFile);
    }

    _file = file;

    if (registerInGameStorage) {
      game.onResourceAdd(referencedFile);
    }
  }

  /// Deletes the resource's file reference.
  Future<void> delete() => _deleteObsoleteFile(referencedFile);

  /// Deletes the resource's file reference (unawaited).
  void deleteInBackground() => delete();

  /// Deletes a file which is no longer used.
  Future<void> _deleteObsoleteFile(File file) async {
    if (file != null && await file.exists()) {
      await game.onResourceRemove(file, notifyGM: false);
      await file.delete();
    }
  }

  static Future<ControlledResource> create(
    Game game, {
    String fileExtension = defaultFileExension,
    File file,
  }) async {
    file ??= await newRandomFileName(game.resources, fileExtension);
    await file.create(recursive: true);

    final resFile = GameFile.fromFile(game, file);

    return ControlledResource(game, resFile, fileExtension: fileExtension);
  }

  /// Returns a new (= non-existent) file located in the `parent` directory
  /// with a given `fileExtension`.
  static Future<File> newRandomFileName(
      Directory parent, String fileExtension) async {
    File file;
    do {
      final basename = _randomBasename();
      final fileName = '$basename.$fileExtension';

      final filePath = path.join(parent.path, fileName);

      file = File(filePath);
    } while (await file.exists());

    return file;
  }

  static String _randomBasename() {
    return randomAlphaNumeric(fileNameCharacters);
  }
}

abstract class ResourceFile {
  final String path;
  final File reference;

  ResourceFile(this.path, this.reference);

  static ResourceFile parse(Game game, String filePath) {
    if (filePath.startsWith('assets/')) {
      return AssetFile(filePath);
    }
    return GameFile(game, filePath);
  }
}

class AssetFile extends ResourceFile {
  /// `path` should start with "assets/".
  AssetFile(String path) : super(path, File('web/images/$path'));

  AssetFile.fromFile(File file)
      : super('assets/' + path.basename(file.path), file);
}

class GameFile extends ResourceFile {
  final Game game;

  GameFile(this.game, String fileName)
      : super(
          fileName,
          File(path.join(game.resources.path, fileName)),
        );

  GameFile.fromFile(this.game, File file)
      : super(path.basename(file.path), file);
}
