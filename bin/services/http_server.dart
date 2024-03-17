import 'dart:convert';
import 'dart:io';

import 'package:dungeonclub/environment.dart';
import 'package:graceful/graceful.dart';
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_web_socket/shelf_web_socket.dart' as ws;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import '../connections.dart';
import '../server.dart';
import '../util/untaint.dart';
import 'asset_provider.dart';
import 'service.dart';

class HttpServerService extends StartableService {
  static const _hostname = '0.0.0.0';
  static const _githubUrl =
      'https://raw.githubusercontent.com/doodlezucc/dungeonclub/master';

  final DungeonClubServer dungeonClub;
  final int port;

  late final HttpServer httpServer;
  late final String publicAddress;

  HttpServerService(this.dungeonClub, {required this.port});

  @override
  Future<void> startService() async {
    var handler = const Pipeline()
        .addMiddleware(createMiddleware(
          responseHandler: _corsHandler,
        ))
        .addHandler(_handleRequest);

    httpServer = await io.serve(handler, _hostname, port);

    final config = File('config');
    if (await config.exists()) {
      publicAddress = (await config.readAsString()).trim();
    } else {
      publicAddress = 'http://${await _getNetworkIP()}:$port';
    }
  }

  @override
  Future<void> dispose() async {
    await httpServer.close();
  }

  static Future<String> _getNetworkIP() async {
    final available =
        await NetworkInterface.list(type: InternetAddressType.IPv4);
    return available[0].addresses[0].address;
  }

  // TODO: this is insecure, isn't it
  static Response _corsHandler(Response response) => response.change(headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST',
        'Access-Control-Allow-Headers': 'Origin, Content-Type, X-Auth-Token',
      });

  static String? getMimeType(File f) {
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
      case '.svg':
        return 'image/svg+xml';
    }
    return null;
  }

  void _onWebSocketConnect(WebSocketChannel ws) => onConnect(dungeonClub, ws);

  Future<Response> _handleRequest(Request request) async {
    if (!Bootstrapper.isRunning) {
      return Response.forbidden('Server is shutting down.');
    }

    var urlPath = Uri.decodeComponent(request.url.path);

    if (urlPath == 'ws') {
      return await ws.webSocketHandler(_onWebSocketConnect,
          pingInterval: pingInterval)(request);
    } else if (urlPath.isEmpty || urlPath == 'home') {
      urlPath = 'index.html';
    } else if (urlPath == 'privacy') {
      urlPath += '.html';
    } else if (urlPath.endsWith('.mp4')) {
      var vid = urlPath.substring(urlPath.lastIndexOf('/'));
      return Response.seeOther('$_githubUrl/web/videos$vid', headers: {
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
        return Response.seeOther('$publicAddress/images/assets/default_pc.jpg');
      } else if (!urlPath.startsWith('game/') && urlPath.isNotEmpty) {
        return _notFound(request);
      } else {
        file = File('web/index.html');
      }
    }

    // Embed current environment variables in frontend
    List<int>? bodyOverride;
    if (Environment.isCompiled && file.path == 'web/index.html') {
      final htmlBody = await _injectEnvironmentInFrontend(file);
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

  static Future<String> _injectEnvironmentInFrontend(File indexHtml) async {
    // Matches the inner HTML of a <script> with the "data-environment" attribute.
    final regex = RegExp(r'(?<=<script data-environment>).*?(?=<\/script>)');

    final contents = await indexHtml.readAsString();
    final envJson = jsonEncode(Environment.frontendInjectionEntries);
    return contents.replaceFirst(regex, 'window.ENV = $envJson');
  }

  static Response _notFound(Request request) {
    return Response.notFound('Request for "${request.url}"');
  }
}
