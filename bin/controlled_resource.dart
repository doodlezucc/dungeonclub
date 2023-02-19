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
  File _file;

  Directory get parentDirectory => game.resources;
  String get filePath => _file?.path;

  ControlledResource(
    this.game,
    File file, {
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
  }) : this(game, File(filePath), fileExtension: fileExtension);

  /// Creates a new file reference and optionally deletes the previous one.
  Future<File> replace({bool deletePrevious = true}) async {
    final newFile = await newRandomFileName(parentDirectory, fileExtension);
    await newFile.create(recursive: true);

    replaceWithFile(
      newFile,
      deletePrevious: deletePrevious,
      registerInGameStorage: false,
    );

    return newFile;
  }

  /// Replaces the current file reference with a new one.
  void replaceWithFile(
    File file, {
    bool deletePrevious = true,
    bool registerInGameStorage = true,
  }) {
    if (file == _file) return;

    if (deletePrevious) {
      _deleteObsoleteFile(_file);
    }

    _file = file;

    if (registerInGameStorage) {
      game.onResourceAdd(_file);
    }
  }

  /// Deletes the resource's file reference.
  Future<void> delete() => _deleteObsoleteFile(_file);

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

    return ControlledResource(game, file, fileExtension: fileExtension);
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
