import '../main.dart';
import 'communication.dart';

class Resource {
  final String _path;

  String _currentPath;
  String get url => _currentPath;

  Resource(String path) : _path = getFile(path, cacheBreak: false) {
    _currentPath = _path;
  }

  String reload() {
    // Add random query parameter to reload the same URL
    _currentPath = '$_path?${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
    return _currentPath;
  }
}

class GameResource extends Resource {
  GameResource(String path, {String gameId}) : super(_gameFile(path, gameId));

  static String _gameFile(String path, String gameId) {
    gameId ??= user?.session?.id;
    return 'database/games/$gameId/$path';
  }
}
