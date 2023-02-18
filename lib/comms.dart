import 'dart:async';
import 'dart:convert';

import 'dart:math';

final confidentialRegex = RegExp(r'email|password|token|gameJoin');
const msgPrintLength = 200;
const maxMsgLength = 1024 * 1024 * 20;

abstract class Socket {
  final _jobs = <int>[];

  Stream get messageStream;
  Future<void> send(dynamic data);
  Future handleAction(String action, [Map<String, dynamic> params]);

  String modifyLog(String message) => message;

  StreamSubscription listen({void Function() onDone, Function onError}) =>
      messageStream.listen(_onMessage, onDone: onDone, onError: onError);

  Future<void> _onMessage(data) async {
    if (data is String) {
      var s = data;
      final short =
          s.length <= msgPrintLength ? s : s.substring(0, msgPrintLength);

      if (!confidentialRegex.hasMatch(short)) {
        print(modifyLog(short));
      }

      if (s[0] == '{') {
        if (s.length >= maxMsgLength) {
          print('Warning: Long websocket message (${s.length} chars)');

          if (!short.startsWith('{"id"')) return;

          print('shortening');
          // Shorten json string to only contain message id
          s = short.substring(0, max(1, short.indexOf('"params"') + 10)) + '}}';
          print(s);
        }

        final json = jsonDecode(s);
        dynamic result;

        try {
          // Send normal response on success
          result = await handleAction(json['action'], json['params']);
        } on ResponseError catch (err) {
          // Send error response with custom context
          result = err.toJson();
          rethrow;
        } catch (err) {
          // Send error response
          result = {'error': '$err'};
          rethrow;
        } finally {
          // Always send a response
          final id = json['id'];
          if (id != null) {
            await send('r' + jsonEncode({'id': id, 'result': result}));
          }
        }
      }
    } else {
      handleBinary(data);
    }
  }

  void handleBinary(data);

  Future request(String action, [Map<String, dynamic> params]) async {
    var myId = _jobs.isEmpty ? 0 : _jobs.last + 1;
    _jobs.add(myId);

    var json = jsonEncode({
      'id': myId,
      'action': action,
      if (params != null) 'params': params,
    });
    await send(json);

    String msg = await messageStream.firstWhere(
        (data) => data is String && data.startsWith('r{"id":$myId,'),
        orElse: () => null);

    _jobs.remove(myId);

    if (msg == null) return null;

    final result = jsonDecode(msg.substring(1))['result'];

    if (result is Map && result['error'] != null) {
      throw ResponseError.fromJson(result);
    }

    return result;
  }

  Future<void> sendAction(String action, [Map<String, dynamic> params]) async {
    var json = jsonEncode({
      'action': action,
      if (params != null) 'params': params,
    });
    return send(json);
  }
}

class ResponseError extends Error {
  final String errorMessage;
  final Map<String, dynamic> context;

  ResponseError(this.errorMessage, this.context);
  ResponseError.fromJson(json)
      : this(
          json['error'],
          json['context'] ?? const {},
        );

  Map<String, dynamic> toJson() => {
        'error': errorMessage,
        'context': context,
      };

  @override
  String toString() => errorMessage;
}
