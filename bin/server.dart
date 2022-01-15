import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_web_socket/shelf_web_socket.dart' as ws;

import 'asset_provider.dart';
import 'audio.dart';
import 'autosave.dart';
import 'connections.dart';
import 'data.dart';
import 'mail.dart';
import 'maintenance.dart';
import 'untaint.dart';

// For Google Cloud Run, set _hostname to '0.0.0.0'.
const _hostname = 'localhost';
const githubUrl =
    'https://raw.githubusercontent.com/doodlezucc/dungeonclub/master';

String _address;
String get address => _address;

final data = ServerData();
final autoSaver = AutoSaver(data);
final maintainer = Maintainer('maintenance');
final accountMaintainer = AccountMaintainer('account');
const wsPing = Duration(seconds: 15);

void main(List<String> args) async {
  if (await maintainer.file.exists()) {
    print('Server restart blocked by maintenance file!');
    await Future.delayed(Duration(seconds: 5));
    return;
  }

  var parser = ArgParser()..addOption('port', abbr: 'p');
  var result = parser.parse(args);

  // For Google Cloud Run, we respect the PORT environment variable
  var portStr = result['port'] ?? Platform.environment['PORT'] ?? '7070';
  var port = int.tryParse(portStr);

  if (port == null) {
    stdout.writeln('Could not parse port value "$portStr" into a number.');
    // 64: command line usage error
    exitCode = 64;
    return;
  }

  data.init();

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

  _address = _address?.trim() ?? 'http://${server.address.host}:${server.port}';
  print('Serving at $address');

  await initializeMailServer();
  autoSaver.init();
  maintainer.autoCheckForFile();
  accountMaintainer.autoCheckForFile();
  listenToExit();

  await createAssetPreview('web/images/assets/pc', tileSize: 240, usePng: true);
  // await resizeAll('web/images/assets/scene');
  await createAssetPreview('web/images/assets/scene', zoomIn: true);

  try {
    await loadAmbience();
    print('Ambience audio is up to date!');
  } on Exception catch (e) {
    print(e.toString());
    print('Failed to extract ambience track sources.'
        ' If you require the integrated audio player,'
        ' make sure you have youtube-dl and ffmpeg installed.');
  }
}

void onExit() async {
  try {
    await Future.wait([data.save(), sendPendingFeedback()]);
  } finally {
    exit(0);
  }
}

void listenToExit() {
  var shuttingDown = false;
  ProcessSignal.sigint.watch().forEach((signal) {
    if (!shuttingDown) {
      shuttingDown = true;
      onExit();
    }
  });
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
  var path = request.url.path;

  if (path == 'ws') {
    return await ws.webSocketHandler(onConnect, pingInterval: wsPing)(request);
  } else if (path.isEmpty || path == 'home') {
    path = 'index.html';
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

  if (path.contains('/assets/')) path = Uri.decodeComponent(path);

  var file = isDataFile
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
