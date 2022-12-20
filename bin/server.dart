import 'dart:async';
import 'dart:io';

import 'package:dungeonclub/environment.dart';
import 'package:graceful/graceful.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_web_socket/shelf_web_socket.dart' as ws;

import 'entry_parser.dart';
import 'asset_provider.dart';
import 'audio.dart';
import 'autosave.dart';
import 'connections.dart';
import 'data.dart';
import 'mail.dart';
import 'maintenance.dart';
import 'untaint.dart';

const _hostname = '0.0.0.0';
const githubUrl =
    'https://raw.githubusercontent.com/doodlezucc/dungeonclub/master';

String _address;
String get address => _address;

final data = ServerData();
final autoSaver = AutoSaver(data);
final maintainer = Maintainer('maintenance');
final accountMaintainer = AccountMaintainer('account');
final httpClient = http.Client();
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

void main(List<String> args) async {
  resetCurrentWorkingDir();

  // Handle "mail" argument
  final runMailSetup = args.contains('mail');
  if (runMailSetup) {
    return await setupMailAuth();
  }

  // Check for maintenance file
  if (await maintainer.file.exists()) {
    print('Server restart blocked by maintenance file!');
    await Future.delayed(Duration(seconds: 5));
    return exit(1);
  }

  // Start server in given bootstrap mode
  final D = serverParser.tryArgParse(args);
  final bootstrapMode = D[SERVE_BOOTSTRAP];

  if (bootstrapMode == SERVE_BOOTSTRAP_NONE) {
    return run(args);
  }

  final logFile = 'logs/latest.log';
  return bootstrap(
    run,
    args: args,
    fileOut: logFile,
    fileErr: logFile,
    enableChildProcess:
        bootstrapMode == SERVE_BOOTSTRAP_ALL || Environment.isCompiled,
    onExit: onExit,
    exitAfterBody: false,
  );
}

void run(List<String> args) async {
  var D = serverParser.tryArgParse(args);
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

  var server = await io.serve(handler, _hostname, port);

  var config = File('config');
  if (await config.exists()) {
    _address = await config.readAsString();
  }

  var servePort = server.port;
  _address = _address?.trim() ?? 'http://${await _getNetworkIP()}:$servePort';

  await initializeMailServer();
  autoSaver.init();
  maintainer.autoCheckForFile();
  accountMaintainer.autoCheckForFile();

  await createAssetPreview('web/images/assets/pc', tileSize: 240, usePng: true);
  await createAssetPreview('web/images/assets/scene', zoomIn: true);

  if (Environment.enableMusic) {
    await loadAmbience();
    print('Loaded music playlists');
  } else {
    print('Music playlists not enabled');
  }

  print('''\nDungeon Club is ready!
  - Local:   http://localhost:$servePort
  - Network: $address
''');
}

Future<String> _getNetworkIP() async {
  final available = await NetworkInterface.list(type: InternetAddressType.IPv4);
  return available[0].addresses[0].address;
}

final serverParser =
    EntryParser(Environment.defaultConfigServe, prepend: (argParser, addFlag) {
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

void resetCurrentWorkingDir() {
  var exe = Platform.script.toFilePath();
  var root = p.dirname(exe);
  if (p.extension(exe) == '.dart') root = p.dirname(root);
  Directory.current = root;
}

Future<int> onExit() async {
  try {
    httpClient.close();
    await Future.wait([data.save(), sendPendingFeedback(), closeMailServer()]);
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
          data.accounts.add(Account(name, password));
          print('Registered mock account "$name"');
        }
      }
    }
  }
}

String getMimeType(File f) {
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
  return 'text/plain';
}

Future<Response> _handleRequest(Request request) async {
  if (!Bootstrapper.isRunning) {
    return Response.forbidden('Server is shutting down.');
  }

  var path = request.url.path;

  if (path == 'ws') {
    return await ws.webSocketHandler(onConnect, pingInterval: wsPing)(request);
  } else if (path.isEmpty || path == 'home') {
    path = 'index.html';
  } else if (path == 'privacy') {
    path += '.html';
  } else if (path.endsWith('.mp4')) {
    var vid = path.substring(path.lastIndexOf('/'));
    return Response.seeOther('$githubUrl/web/videos$vid', headers: {
      'Set-Cookie': '',
    });
  } else if (path == 'online') {
    var count = connections.length;
    var loggedIn = connections.where((e) => e.account != null).length;
    return Response.ok('Connections: $count\nLogged in: $loggedIn');
  } else if (path.startsWith('untaint')) {
    return untaint(request, _notFound);
  }

  var isDataFile =
      path.startsWith('database/games') || path.startsWith('ambience/');

  File file;
  if (path.contains('/assets/')) {
    path = Uri.decodeComponent(path);
    if (!path.contains('-preview')) {
      file = await getAssetFile(path);
    }
  }

  file ??= isDataFile
      ? File(path)
      : (path.startsWith('game')
          ? File('web/' + path.substring(5))
          : File('web/' + path));

  if (!await file.exists()) {
    if (isDataFile && path.contains('/pc')) {
      return Response.seeOther('$address/images/default_pc.jpg');
    } else if (!path.startsWith('game/') && path.isNotEmpty) {
      return _notFound(request);
    } else {
      file = File('web/index.html');
    }
  }

  var type = isDataFile ? 'image/jpeg' : getMimeType(file);
  var length = await file.length();
  return Response(
    200,
    body: file.openRead(),
    headers: {
      'Content-Type': type,
      'Content-Length': '$length',
      'Content-Range': 'bytes */$length',
      'Accept-Ranges': 'bytes',
    },
  );
}

Response _notFound(Request request) {
  return Response.notFound('Request for "${request.url}"');
}
