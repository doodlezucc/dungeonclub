import 'dart:io';

import 'package:sass/sass.dart' as sass;
import './server.dart' as server;

void main(List<String> args) async {
  await startScssWatchCycle();

  server.main(args);
}

void _devPrint(dynamic message) {
  print('[Dev] $message');
}

Future<void> startScssWatchCycle() async {
  final sassDirectory = Directory('web/sass');
  final src = '${sassDirectory.path}/style.scss';

  final dst = 'web/style/style.css';
  final dstFile = File(dst);

  await _compileScssToCss(src, dstFile);

  var isCompiling = false;

  sassDirectory.watch(recursive: true).forEach((fse) async {
    if (isCompiling) return;

    isCompiling = true;
    await _compileScssToCss(src, dstFile);
    isCompiling = false;
  });

  _devPrint('Watching for stylesheet changes');
}

Future<void> _compileScssToCss(String src, File dstFile) async {
  try {
    final compileResult = sass.compileToResult(
      src,
      style: sass.OutputStyle.compressed,
    );

    await dstFile.writeAsString(compileResult.css);
  } on sass.SassException catch (error) {
    print('\n$error\n');
  }
}
