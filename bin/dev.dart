import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:sass/sass.dart' as sass;

void main(List<String> args) async {
  final webdevProcess = WebdevProcess();
  final stylesheetProcess = StylesheetProcess();
  final backendProcess = BackendProcess(args);

  await webdevProcess.startCycle();
  await stylesheetProcess.startCycle();
  await backendProcess.startCycle();
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

enum BackendState { INACTIVE, STARTING, RUNNING, EXITING }

class BackendProcess extends DevProcess {
  final List<String> _args;
  BackendState _state = BackendState.INACTIVE;

  /// Port to send messages to the server.
  late SendPort _serverSender;

  /// A stream of messages sent by the server.
  late Stream _signalsFromServer;

  BackendProcess(List<String> args)
      : _args = args,
        super('Backend');

  /// Starts the backend server (at "bin/server.dart") in a new isolate process.
  /// Returns the isolate after the server is fully started.
  Future<void> startNewBackendIsolate() async {
    if (_state != BackendState.INACTIVE) {
      throw StateError('Isolate is already active');
    }

    _state = BackendState.STARTING;

    devPrint('Spawning backend server isolate');
    print(''); // Empty line

    final completer = Completer<SendPort>();

    final serverReceiver = ReceivePort();
    _signalsFromServer = serverReceiver.asBroadcastStream();

    // Wait for a message to be sent to the receiver port.
    _signalsFromServer.first.then((port) => completer.complete(port));

    await Isolate.spawnUri(
      Uri.file('./server.dart'),
      _args,
      serverReceiver.sendPort,
    );

    _serverSender = await completer.future;
    _state = BackendState.RUNNING;
  }

  /// Kills the active server isolate process.
  Future<void> killIsolate() async {
    if (_state == BackendState.EXITING) {
      throw StateError('Isolate is already exiting');
    }

    _state = BackendState.EXITING;
    _serverSender.send(null);

    // Wait for isolate to shutdown gracefully
    await _signalsFromServer.first;

    _state = BackendState.INACTIVE;
    devPrint('Exited server');
  }

  /// Kills the active isolate and waits for a new one to start.
  Future<void> restart() async {
    if (!(_state == BackendState.STARTING || _state == BackendState.RUNNING)) {
      throw StateError('Invalid state $_state');
    }

    await killIsolate();
    await startNewBackendIsolate();
  }

  /// Starts the backend server and listens to stdin for control keypresses.
  Future<void> startCycle() async {
    await startNewBackendIsolate();

    stdin.echoMode = false;
    stdin.lineMode = false;

    stdin.listen((data) async {
      final char = String.fromCharCodes(data)[0];

      switch (char.toLowerCase()) {
        case 'r':
          if (_state != BackendState.EXITING) {
            restart();
          }
          break;
      }
    });

    devPrint('Press R to restart the backend server');
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
  static const compileCooldownMs = 500;

  static final sassDirectory = Directory('web/sass');
  static final srcPath = '${sassDirectory.path}/style.scss';
  static final dstFile = File('web/style/style.css');

  bool _lastCompileWasError = false;
  int _lastCompileTimestamp = 0;

  StylesheetProcess() : super('CSS');

  @override
  Future<void> startCycle() async {
    await compileScssToCss(srcPath, dstFile);

    sassDirectory.watch(recursive: true).forEach((fse) async {
      final currentTimestamp = DateTime.now().millisecondsSinceEpoch;
      final sinceLastCompile = currentTimestamp - _lastCompileTimestamp;

      // On Windows, a single file change gets detected twice.
      // As a workaround, a cooldown is set.
      if (sinceLastCompile > compileCooldownMs) {
        _lastCompileTimestamp = currentTimestamp;
        await compileScssToCss(srcPath, dstFile);
      }
    });

    devPrint('Watching for stylesheet changes');
  }

  Future<void> compileScssToCss(String src, File dstFile) async {
    try {
      final compileResult = sass.compileToResult(
        src,
        style: sass.OutputStyle.compressed,
      );

      await dstFile.writeAsString(compileResult.css);

      if (_lastCompileWasError) {
        _lastCompileWasError = false;
        devPrint('Compiled stylesheet without errors');
      }
    } on sass.SassException catch (error) {
      _lastCompileWasError = true;
      devPrint('\n$error\n');
    }
  }
}
