import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_web_socket/shelf_web_socket.dart' as ws;

import 'autosave.dart';
import 'connections.dart';
import 'data.dart';
import 'mail.dart';
import 'maintenance.dart';

// For Google Cloud Run, set _hostname to '0.0.0.0'.
const _hostname = 'localhost';

String _address;
String get address => _address;

final data = ServerData();
final autoSaver = AutoSaver(data);
final maintainer = Maintainer('maintenance');

void main(List<String> args) async {
  if (await maintainer.timeFile.exists()) {
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

  var handler = const Pipeline()
      .addMiddleware(_fixCORS)
      .addMiddleware(logRequests())
      .addHandler(_echoRequest);

  var server = await io.serve(handler, _hostname, port);

  var config = File('config');
  if (await config.exists()) {
    _address = await config.readAsString();
  }

  _address = _address?.trim() ?? 'http://${server.address.host}:${server.port}';
  print('Serving at $address');

  await initializeMailServer();
  autoSaver.init();
  maintainer.autoCheckForScheduleFile();
  listenToExit();
}

void onExit() async {
  try {
    await data.save();
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
  switch (path.extension(f.path)) {
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
  }
  return 'text/plain';
}

Future<Response> _echoRequest(Request request) async {
  var path = request.url.path;

  if (path == 'ws') {
    return await ws.webSocketHandler(onConnect)(request);
  } else if (path.isEmpty || path == 'home') {
    path = 'index.html';
  }

  var isDataFile = path.startsWith('database/games');

  var file = isDataFile
      ? File(path)
      : (path.startsWith('game')
          ? File('web/' + path.substring(5))
          : File('web/' + path));

  if (!await file.exists()) {
    if (!path.startsWith('game/') && path.isNotEmpty) {
      return Response.notFound('Request for "${request.url}"');
    }

    file = File('web/index.html');
  }

  var type = isDataFile ? 'image/jpeg' : getMimeType(file);
  return Response(
    200,
    body: file.openRead(),
    headers: {'Content-Type': type},
  );
}
