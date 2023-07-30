import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sass/sass.dart' as sass;
import './server.dart' as server;

void main(List<String> args) async {
  await startScssWatchCycle();
  await startWebdevServer();

  print(''); // Empty line

  server.main(args);
}

void _devPrint(dynamic message, String process) {
  final prefix = '[Dev: $process]';
  final prefixedMessage =
      '$message'.split('\n').map((line) => '$prefix $line').join('\n');

  print(prefixedMessage);
}

Future<void> startWebdevServer() async {
  final process = await Process.start('dart', [
    'pub',
    'global',
    'run',
    'webdev',
    'serve',
  ]);

  final whenReady = Completer<bool>();

  // Fail if the program exits before the first compile success
  process.exitCode.then((_) {
    if (!whenReady.isCompleted) {
      whenReady.complete(false);
    }
  });

  process.stdout.listen((data) {
    if (!whenReady.isCompleted) {
      stdout.add(data);

      final message = utf8.decode(data);
      if (message.contains('Succeeded after')) {
        whenReady.complete(true);
      }
    }
  });

  process.stderr.listen((data) {
    final message = utf8.decode(data);
    _devPrint(message, 'Web');
  });

  _devPrint('Starting webdev server...\n', 'Web');
  final isReady = await whenReady.future;

  if (isReady) {
    _devPrint('\nWebsite serving at http://localhost:8080', 'Web');
  } else {
    throw 'Unable to start webdev server';
  }
}

Future<void> startScssWatchCycle() async {
  final sassDirectory = Directory('web/sass');
  final src = '${sassDirectory.path}/style.scss';

  final dst = 'web/style/style.css';
  final dstFile = File(dst);

  await _compileScssToCss(src, dstFile);

  var isCompiling = false;

  sassDirectory.watch(recursive: true).forEach((fse) async {
    if (!isCompiling) {
      isCompiling = true;

      await _compileScssToCss(src, dstFile);
      isCompiling = false;
    }
  });

  _devPrint('Watching for stylesheet changes', 'CSS');
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
