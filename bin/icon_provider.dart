import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:dnd_interactive/game_icons.dart';
import 'package:path/path.dart';

class TokenIconProvider {
  final Directory directory;

  TokenIconProvider(String directory) : directory = Directory(directory);

  Future<void> initialize(String zipFile) async {
    await extractIcons(zipFile);
  }

  Future<void> extractIcons(String zipFile) async {
    if (!await directory.exists()) {
      var tmp = Directory('icons_tmp');

      print('Extracting game icons...');
      extractFileToDisk(zipFile, tmp.path);

      var extracted = Directory(join(tmp.path, 'icons'));
      var artistDir = Directory(join(extracted.path, 'ffffff/transparent/1x1'));
      var license = File(join(extracted.path, 'license.txt'));

      await artistDir.rename(directory.path);
      await license.rename(join(directory.path, 'license.txt'));

      await tmp.delete(recursive: true);
      print('Done!');
    }
  }

  Future<List<Icon>> searchIcons(String query) async {
    query = query.toLowerCase();
    var files = await directory
        .list(recursive: true, followLinks: false)
        .where((file) => file.path.contains(query))
        .take(20)
        .toList();

    return files.map((e) => Icon(e.path)).toList()
      ..sort((a, b) {
        if (_isSuperior(a.name, query)) {
          return -1;
        } else if (_isSuperior(b.name, query)) {
          return 1;
        }
        return a.name.compareTo(b.name);
      });
  }

  bool _isSuperior(String s, String q) {
    var regex = RegExp('(\\s|^)$q(\\s|\$)', caseSensitive: false);
    return regex.hasMatch(s);
  }
}
