import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:sass/sass.dart' as sass;

void main(List<String> args) async {
  final stylesheetProcess = StylesheetProcess();
  final webdevProcess = WebdevProcess();
  final backendProcess = BackendProcess(args);

  await stylesheetProcess.startCycle();
  // await webdevProcess.startCycle();

  print(''); // Empty line

  // await backendProcess.startCycle();
}

abstract class DevProcess {
  final String name;

  DevProcess(this.name);

  void devPrint(dynamic message) {
    final prefix = '[Dev: $name]';
    final prefixedMessage =
        '$message'.split('\n').map((line) => '$prefix $line').join('\n');

    print(prefixedMessage);
  }

  Future<void> startCycle();
}

class BackendProcess extends DevProcess {
  final List<String> _args;
  Isolate? _serverIsolate;

  bool get isStarting => _serverIsolate != null;

  BackendProcess(List<String> args)
      : _args = args,
        super('Backend');

  /// Starts the backend server (at "bin/server.dart") in a new isolate process.
  /// Returns the isolate after the server is fully started.
  Future<Isolate> _startNewBackendIsolate() async {
    devPrint('Spawning backend server isolate...');
    final completer = Completer();

    // Wait for a message to be sent to the receiver port.
    final receiver = ReceivePort();
    receiver.first.then(completer.complete);

    final isolate = await Isolate.spawnUri(
      Uri.file('./server.dart'),
      _args,
      receiver.sendPort,
    );

    await completer.future;

    return isolate;
  }

  /// Kills the active server isolate process.
  void killIsolate() {
    if (_serverIsolate != null) {
      _serverIsolate!.kill();
      _serverIsolate = null;

      devPrint('Exited server');
    }
  }

  /// Kills the active isolate and waits for a new one to start.
  Future<void> restart() async {
    if (isStarting) return;

    killIsolate();
    _serverIsolate = await _startNewBackendIsolate();
  }

  /// Starts the backend server and listens to stdin for control keypresses.
  Future<void> startCycle() async {
    await _startNewBackendIsolate();

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

    devPrint('Press [R] to restart the backend server');
  }
}

class WebdevProcess extends DevProcess {
  WebdevProcess() : super('Web');

  @override
  Future<void> startCycle() async {
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

    // Pipe webdev's stdout until the first compilation is complete
    process.stdout.listen((data) {
      if (!whenReady.isCompleted) {
        stdout.add(data);

        final message = utf8.decode(data);
        if (message.contains('Succeeded after')) {
          whenReady.complete(true);
        }
      }
    });

    // Pipe webdev's stderr
    process.stderr.listen((data) {
      final message = utf8.decode(data);
      devPrint(message);
    });

    devPrint('Starting webdev server...\n');
    final isReady = await whenReady.future;

    if (isReady) {
      devPrint('\nWebsite serving at http://localhost:8080');
    } else {
      throw 'Unable to start webdev server';
    }
  }
}

class StylesheetProcess extends DevProcess {
  bool _isCompiling = false;

  StylesheetProcess() : super('CSS');

  @override
  Future<void> startCycle() async {
    final sassDirectory = Directory('web/sass');
    final src = '${sassDirectory.path}/style.scss';

    final dst = 'web/style/style.css';
    final dstFile = File(dst);

    await _compileScssToCss(src, dstFile);

    sassDirectory.watch(recursive: true).forEach((fse) async {
      if (!_isCompiling) {
        await _compileScssToCss(src, dstFile);
      }
    });

    devPrint('Watching for stylesheet changes');
  }

  Future<void> _compileScssToCss(String src, File dstFile) async {
    _isCompiling = true;

    try {
      final compileResult = sass.compileToResult(
        src,
        style: sass.OutputStyle.compressed,
      );

      await dstFile.writeAsString(compileResult.css);
    } on sass.SassException catch (error) {
      devPrint('\n$error\n');
    } finally {
      _isCompiling = false;
    }
  }
}
