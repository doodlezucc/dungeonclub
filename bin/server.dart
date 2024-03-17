import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:dungeonclub/environment.dart';
import 'package:graceful/graceful.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import 'audio.dart';
import 'data.dart';
import 'services/account_removal.dart';
import 'services/asset_provider.dart';
import 'services/auto_save.dart';
import 'services/feedback_push.dart';
import 'services/http_server.dart';
import 'services/mail.dart';
import 'services/maintenance_switch.dart';
import 'services/service.dart';
import 'util/entry_parser.dart';
import 'util/mail_setup.dart';

const SERVE_PORT = 'port';
const SERVE_BOOTSTRAP = 'bootstrap';
const SERVE_BOOTSTRAP_NONE = 'none';
const SERVE_BOOTSTRAP_LOGGING = 'logging';
const SERVE_BOOTSTRAP_ALL = 'all';
const SERVE_BOOTSTRAP_ALLOWED = [
  SERVE_BOOTSTRAP_NONE,
  SERVE_BOOTSTRAP_LOGGING,
  SERVE_BOOTSTRAP_ALL,
];

final httpClient = http.Client();

void main(List<String> args, [SendPort? signalsToParent]) async {
  resetCurrentWorkingDir();
  final server = DungeonClubServer();

  // Handle "mail" argument
  final runMailSetup = args.contains('mail');
  if (runMailSetup) {
    return await setupMailAuth();
  }

  // Check for maintenance file
  if (await server.maintenanceSwitchService.doesFileExist()) {
    print('Server restart blocked by maintenance file!');
    await Future.delayed(Duration(seconds: 5));
    exit(1);
  }

  // Start server in given bootstrap mode
  final D = DungeonClubServer.argParser.tryArgParse(args);
  final bootstrapMode = D[SERVE_BOOTSTRAP];

  final logFile = 'logs/latest.log';
  final enableLogging = bootstrapMode != SERVE_BOOTSTRAP_NONE;
  final enableChildProcess =
      bootstrapMode == SERVE_BOOTSTRAP_ALL || Environment.isCompiled;

  final signalsFromParent = ReceivePort();
  signalsFromParent.first.then((_) async {
    await server.shutdown();

    // Notify the development launch script that the server has exited
    signalsToParent!.send(null);
    Isolate.current.kill(); // Kill any dangling asynchronous futures
  });

  return bootstrap(
    (args) async {
      await server.start(args);

      if (signalsToParent != null) {
        // Notify the development launch script that the server
        // is now started
        signalsToParent.send(signalsFromParent.sendPort);
      }
    },
    args: args,
    fileOut: logFile,
    fileErr: logFile,
    enableLogFiles: enableLogging,
    enableChildProcess: enableChildProcess,
    onExit: server.onExit,
    exitAfterBody: false,
  );
}

void resetCurrentWorkingDir() {
  var exe = Platform.script.toFilePath();
  var root = path.dirname(exe);
  if (path.extension(exe) == '.dart') root = path.dirname(root);
  Directory.current = root;
}

class DungeonClubServer {
  String get address => httpServerService.publicAddress;

  late final ServerData data = ServerData(this);

  late final FeedbackPushService feedbackPushService;
  late final HttpServerService httpServerService;
  late final MailService mailService;
  late final MaintenanceSwitchService maintenanceSwitchService;

  late final List<Service> services;

  Future<void> start(List<String> args) async {
    print('Starting server...');

    var D = argParser.tryArgParse(args);
    Environment.applyConfig(D);

    unawaited(data.init().then((_) {
      if (Environment.enableMockAccount) loadMockAccounts();
    }));

    final portString = D[SERVE_PORT] ?? Platform.environment['PORT'] ?? '7070';
    final port = int.parse(portString);

    services = [
      AccountRemovalService(serverData: data),
      AssetProviderService(),
      AutoSaveService(serverData: data),
      mailService = MailService(),
      feedbackPushService = FeedbackPushService(mailService),
      maintenanceSwitchService = MaintenanceSwitchService(),
      httpServerService = HttpServerService(this, port: port),
    ];

    for (final service in services) {
      service.start();
    }

    if (Environment.enableMusic) {
      await MusicProvider.loadMusicPlaylists();
      print('Loaded music playlists');
    } else {
      print('Music playlists not enabled');
    }

    print('''
Dungeon Club is ready!
  - Local:   http://localhost:$port
  - Network: $address
''');
  }

  static final argParser = EntryParser(Environment.defaultConfigServe,
      prepend: (argParser, addFlag) {
    argParser.addCommand('mail');
    argParser.addOption(
      SERVE_PORT,
      abbr: 'p',
      help: 'Specifies the server port.\n(defaults to 7070)',
    );

    var defaultBoot = SERVE_BOOTSTRAP_LOGGING;
    if (Environment.isCompiled) {
      defaultBoot = SERVE_BOOTSTRAP_ALL;
    } else if (isDebugMode) {
      defaultBoot = SERVE_BOOTSTRAP_NONE;
    }

    argParser.addOption(
      SERVE_BOOTSTRAP,
      aliases: ['boot'],
      allowed: SERVE_BOOTSTRAP_ALLOWED,
      defaultsTo: defaultBoot,
      allowedHelp: {
        SERVE_BOOTSTRAP_NONE: 'Run without additional functionality',
        SERVE_BOOTSTRAP_LOGGING: 'Enable log files',
        SERVE_BOOTSTRAP_ALL:
            'Enable log files and graceful exits (launches in a detached process)'
      },
      help: 'Which parts to enable in the bootstrapper.',
    );
  });

  /// Shuts down the server gracefully.
  Future<void> shutdown() async => await onExit();

  /// Handles server shutdown gracefully and returns an exit code.
  Future<int> onExit() async {
    try {
      httpClient.close();
      await Future.wait([
        data.save(),
        ...services.map((service) => service.dispose()),
      ]);
    } finally {
      // Wait so users can read exit messages
      if (Environment.isCompiled) {
        await Future.delayed(Duration(seconds: 1));
      }

      return 0;
    }
  }

  Future<void> loadMockAccounts() async {
    var separator = ': ';
    var file = File('login.yaml');

    if (await file.exists()) {
      var lines = await file.readAsLines();
      for (var line in lines) {
        if (line.trimLeft().startsWith('#')) continue;

        var index = line.indexOf(separator);
        if (index > 0) {
          var name = line.substring(0, index).trim();
          var password = line.substring(index + 2).trim();

          var acc = data.getAccount(name);
          if (acc != null) {
            acc.setPassword(password);
          } else {
            data.accounts.add(Account(data, name, password));
            print('Registered mock account "$name"');
          }
        }
      }
    }
  }
}
