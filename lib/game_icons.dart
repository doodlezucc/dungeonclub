import 'package:path/path.dart';

class Icon {
  final String path;
  String get name => _titleCase(basenameWithoutExtension(path));
  String get artist => _titleCase(basename(dirname(path)));

  Icon(this.path);

  String _titleCase(String path) => path.splitMapJoin('-',
      onMatch: (m) => ' ',
      onNonMatch: (m) => m[0].toUpperCase() + m.substring(1));

  @override
  String toString() {
    return '"$name" by $artist';
  }
}
