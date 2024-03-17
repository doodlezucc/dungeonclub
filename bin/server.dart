import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:dungeonclub/environment.dart';
import 'package:graceful/graceful.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_web_socket/shelf_web_socket.dart' as ws;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'audio.dart';
import 'config.dart';
import 'connections.dart';
import 'data.dart';
import 'services/account_removal.dart';
import 'services/asset_provider.dart';
import 'services/auto_save.dart';
import 'services/feedback_push.dart';
import 'services/mail.dart';
import 'services/maintenance_switch.dart';
import 'services/service.dart';
import 'util/entry_parser.dart';
import 'util/mail_setup.dart';
import 'util/untaint.dart';

const _hostname = '0.0.0.0';
const githubUrl =
    'https://raw.githubusercontent.com/doodlezucc/dungeonclub/master';

const wsPing = Duration(seconds: 15);

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
  final server = Server();

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
  final D = Server.argParser.tryArgParse(args);
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
  var root = p.dirname(exe);
  if (p.extension(exe) == '.dart') root = p.dirname(root);
  Directory.current = root;
}

class Server {
  String? _address;
  String? get address => _address;

  late final HttpServer httpServer;
  late final ServerData data = ServerData(this);

  late final feedbackPushService = FeedbackPushService(mailService);
  late final mailService = MailService();
  late final maintenanceSwitchService = MaintenanceSwitchService();

  late final List<Service> services = [
    AccountRemovalService(serverData: data),
    AssetProviderService(),
    AutoSaveService(serverData: data),
    feedbackPushService,
    maintenanceSwitchService,
    mailService,
  ];

  Future<void> start(List<String> args) async {
    var D = argParser.tryArgParse(args);
    Environment.applyConfig(D);

    print('Starting server...');

    var portStr = D[SERVE_PORT] ?? Platform.environment['PORT'] ?? '7070';
    var port = int.parse(portStr);

    unawaited(data.init().then((_) {
      if (Environment.enableMockAccount) loadMockAccounts();
    }));

    Response _cors(Response response) => response.change(headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST',
          'Access-Control-Allow-Headers': 'Origin, Content-Type, X-Auth-Token',
        });

    var _fixCORS = createMiddleware(responseHandler: _cors);

    var handler =
        const Pipeline().addMiddleware(_fixCORS).addHandler(_handleRequest);

    httpServer = await io.serve(handler, _hostname, port);

    var config = File('config');
    if (await config.exists()) {
      _address = await config.readAsString();
    }

    var servePort = httpServer.port;
    _address = _address?.trim() ?? 'http://${await _getNetworkIP()}:$servePort';

    _startServices();

    if (Environment.enableMusic) {
      await MusicProvider.loadMusicPlaylists();
      print('Loaded music playlists');
    } else {
      print('Music playlists not enabled');
    }

    print('''\nDungeon Club is ready!
  - Local:   http://localhost:$servePort
  - Network: $address
''');
  }

  void _startServices() {
    for (final service in services) {
      service.start();
    }
  }

  static Future<String> _getNetworkIP() async {
    final available =
        await NetworkInterface.list(type: InternetAddressType.IPv4);
    return available[0].addresses[0].address;
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
        httpServer.close(),
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

  String? getMimeType(File f) {
    switch (p.extension(f.path)) {
      case '.html':
        return 'text/html';
      case '.css':
        return 'text/css';
      case '.js':
        return 'text/javascript';
      case '.png':
        return 'image/png';
      case '.jpg':
        return 'image/jpeg';
      case '.svg':
        return 'image/svg+xml';
    }
    return null;
  }

  void _onWebSocketConnect(WebSocketChannel ws) => onConnect(this, ws);

  Future<Response> _handleRequest(Request request) async {
    if (!Bootstrapper.isRunning) {
      return Response.forbidden('Server is shutting down.');
    }

    var urlPath = Uri.decodeComponent(request.url.path);

    if (urlPath == 'ws') {
      return await ws.webSocketHandler(_onWebSocketConnect,
          pingInterval: wsPing)(request);
    } else if (urlPath.isEmpty || urlPath == 'home') {
      urlPath = 'index.html';
    } else if (urlPath == 'privacy') {
      urlPath += '.html';
    } else if (urlPath.endsWith('.mp4')) {
      var vid = urlPath.substring(urlPath.lastIndexOf('/'));
      return Response.seeOther('$githubUrl/web/videos$vid', headers: {
        'Set-Cookie': '',
      });
    } else if (urlPath == 'online') {
      var count = connections.length;
      var loggedIn = connections.where((e) => e.account != null).length;
      return Response.ok('Connections: $count\nLogged in: $loggedIn');
    } else if (urlPath.startsWith('untaint')) {
      return untaint(request, _notFound);
    }

    final isDataFile =
        urlPath.startsWith('database/games') || urlPath.startsWith('ambience/');

    File? file;
    if (urlPath.startsWith('asset/')) {
      final redirect = await AssetProviderService.resolveIndexedAsset(
        urlPath,
        fullPath: true,
      );

      return Response.movedPermanently('/$redirect');
    }

    file ??= isDataFile
        ? File(path.join(DungeonClubConfig.databasePath, urlPath))
        : (urlPath.startsWith('game')
            ? File('web/' + urlPath.substring(5))
            : File('web/' + urlPath));

    if (!await file.exists()) {
      if (isDataFile && urlPath.contains('/pc')) {
        return Response.seeOther('$address/images/assets/default_pc.jpg');
      } else if (!urlPath.startsWith('game/') && urlPath.isNotEmpty) {
        return _notFound(request);
      } else {
        file = File('web/index.html');
      }
    }

    // Embed current environment variables in frontend
    List<int>? bodyOverride;
    if (Environment.isCompiled && file.path == 'web/index.html') {
      final htmlBody = await injectEnvironmentInFrontend(file);
      bodyOverride = utf8.encode(htmlBody);
    }

    var type = getMimeType(file);
    type ??= isDataFile ? 'image/jpeg' : 'text/html';

    var length = bodyOverride?.length ?? await file.length();
    return Response(
      200,
      body: bodyOverride ?? file.openRead(),
      headers: {
        'Content-Type': type,
        'Content-Length': '$length',
        'Content-Range': 'bytes */$length',
        'Accept-Ranges': 'bytes',
      },
    );
  }

  Future<String> injectEnvironmentInFrontend(File indexHtml) async {
    // Matches the inner HTML of a <script> with the "data-environment" attribute.
    final regex = RegExp(r'(?<=<script data-environment>).*?(?=<\/script>)');

    final contents = await indexHtml.readAsString();
    final envJson = jsonEncode(Environment.frontendInjectionEntries);
    return contents.replaceFirst(regex, 'window.ENV = $envJson');
  }

  Response _notFound(Request request) {
    return Response.notFound('Request for "${request.url}"');
  }
}
