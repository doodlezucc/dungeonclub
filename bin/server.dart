import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_web_socket/shelf_web_socket.dart' as ws;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'data.dart';
import '../web/dart/server_actions.dart';

// For Google Cloud Run, set _hostname to '0.0.0.0'.
const _hostname = 'localhost';

final data = ServerData();

final manualSaveWatch = Stopwatch();

void main(List<String> args) async {
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
  print('Serving at http://${server.address.host}:${server.port}');
}

Future<void> save() async {
  print('saving');
  var json = JsonEncoder.withIndent(' ').convert(data);
  await File('database/data.json').writeAsString(json);
}

Future<Response> handleBackendRequest(Request request) async {
  var ok = Response.ok('ok!');
  var notOk = Response.internalServerError(body: 'not ok!');

  if (request.url.hasQuery) {
    var params = request.url.queryParameters;
    //print(params);
    switch (params['action']) {
      case 'manualSave': // don't know about the safety of this one, chief
        if (manualSaveWatch.elapsedMilliseconds > 10000) {
          await save();
        } else {
          print('Manual saving has a cooldown.');
        }
        manualSaveWatch.reset();
        return ok;
      case PLAYER_CREATE:
        var name = params['name'];
        if (data.players.any((p) => p.name == name)) {
          return notOk;
        }
        data.players.add(ServerPlayer(name, name, params['password']));
        return ok;
      case PLAYER_CHANGE_DISPLAY_NAME:
        var name = params['name'];
        var player =
            data.players.singleWhere((p) => p.name == name, orElse: () => null);
        if (player != null && player.password == params['password']) {
          player.displayName = params['displayName'];
          return ok;
        }
        return notOk;
      case PLAYER_GET:
        var name = params['name'];
        var player =
            data.players.singleWhere((p) => p.name == name, orElse: () => null);
        if (player != null && player.password == params['password']) {
          return Response.ok({'name': name, 'displayName': player.displayName});
        }
        return notOk;
    }
  }

  return Response.notFound('wow 404');
}

String getMimeType(File f) {
  switch (path.extension(f.path)) {
    case '.html':
      return 'text/html';
    case '.css':
      return 'text/css';
    case '.js':
      return 'text/javascript';
  }
  return '';
}

final FutureOr<Response> Function(Request) doWebSocketStuff =
    ws.webSocketHandler((WebSocketChannel webSocket) {
  print('I think there is some sort of connection');
  webSocket.sink.add('shock!');
});

Future<Response> _echoRequest(Request request) async {
  if (request.url.path.isEmpty) {
    return Response.seeOther('index.html');
  } else if (request.url.path == 'ws') {
    return await doWebSocketStuff(request);
    //return await handleBackendRequest(request);
  }

  var file = File('web/' + request.url.path);
  if (await file.exists()) {
    var type = getMimeType(file);
    return Response(
      200,
      body: file.openRead(),
      headers: {'Content-Type': type},
    );
  }

  return Response.notFound('Request for "${request.url}"');
}
