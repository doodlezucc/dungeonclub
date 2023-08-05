import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:sass/sass.dart' as sass;

void main(List<String> args) async {
  // await startScssWatchCycle();
  // await startWebdevServer();

  print(''); // Empty line

  await startBackendServerCycle(args);
}

void _devPrint(dynamic message, String process) {
  final prefix = '[Dev: $process]';
  final prefixedMessage =
      '$message'.split('\n').map((line) => '$prefix $line').join('\n');

  print(prefixedMessage);
}

/// Starts the backend server (at "bin/server.dart") in a new isolate process.
/// Returns the isolate after the server is fully started.
Future<Isolate> _startNewBackendIsolate(List<String> args) async {
  final completer = Completer();

  // Wait for a message to be sent to the receiver port.
  final receiver = ReceivePort();
  receiver.first.then(completer.complete);

  final isolate = await Isolate.spawnUri(
    Uri.file('./server.dart'),
    args,
    receiver.sendPort,
  );

  await completer.future;

  return isolate;
}

/// Starts the backend server and listens to stdin for control keypresses.
Future<void> startBackendServerCycle(List<String> args) async {
  final debugName = 'Backend';
  var isRestarting = false;

  _devPrint('Spawning backend server isolate...', debugName);
  var serverIsolate = await _startNewBackendIsolate(args);

  void restart() async {
    if (isRestarting) return;

    _devPrint('Restarting...', debugName);
    isRestarting = true;
    serverIsolate.kill();

    serverIsolate = await _startNewBackendIsolate(args);

    isRestarting = false;
  }

  stdin.echoMode = false;
  stdin.lineMode = false;

  stdin.listen((data) async {
    final char = String.fromCharCodes(data)[0];

    switch (char.toLowerCase()) {
      case 'r':
        restart();
        break;
    }
  });

  _devPrint('Press [R] to restart the backend server', debugName);
}

Future<void> startWebdevServer() async {
  final debugName = 'Web';
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
    _devPrint(message, debugName);
  });

  _devPrint('Starting webdev server...\n', debugName);
  final isReady = await whenReady.future;

  if (isReady) {
    _devPrint('\nWebsite serving at http://localhost:8080', debugName);
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
