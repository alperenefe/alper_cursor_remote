import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef TrafficCallback = void Function(String direction, String summary, String body);

class CursorWsClient {
  static const connectTimeout = Duration(seconds: 15);

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  String? _authToken;

  bool get isConnected => _channel != null;

  Future<void> connect({
    required String host,
    required int port,
    String? authToken,
    required void Function(String raw) onMessage,
    required void Function(Object error) onError,
    required void Function() onDone,
    TrafficCallback? onTraffic,
  }) async {
    await disconnect();
    final trimmedAuth = authToken?.trim();
    _authToken =
        trimmedAuth != null && trimmedAuth.isNotEmpty ? trimmedAuth : null;

    final uri = Uri.parse('ws://$host:$port');
    onTraffic?.call('out', 'CONNECT', uri.toString());
    final socket = await WebSocket.connect(uri.toString()).timeout(
      connectTimeout,
      onTimeout: () {
        throw TimeoutException(
          'PC\'ye ${connectTimeout.inSeconds} sn içinde ulaşılamadı',
        );
      },
    );
    _channel = IOWebSocketChannel(socket);
    _sub = _channel!.stream.listen(
      (event) {
        final raw = event.toString();
        onTraffic?.call('in', 'WS', raw);
        onMessage(raw);
      },
      onError: (e) {
        onTraffic?.call('in', 'ERROR', e.toString());
        onError(e);
      },
      onDone: () {
        onTraffic?.call('in', 'DONE', 'socket closed');
        onDone();
      },
    );
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void sendAuth({
    String? clientId,
    TrafficCallback? onTraffic,
  }) {
    if (_authToken == null) return;
    sendJson(
      {
        'type': 'auth',
        'token': _authToken,
        if (clientId != null && clientId.isNotEmpty) 'clientId': clientId,
      },
      onTraffic: onTraffic,
    );
  }

  Map<String, dynamic> _withAuth(Map<String, dynamic> payload) {
    if (_authToken != null) {
      payload['authToken'] = _authToken;
    }
    return payload;
  }

  bool sendJson(Map<String, dynamic> payload, {TrafficCallback? onTraffic}) {
    if (_channel == null) return false;
    final body = jsonEncode(_withAuth(payload));
    onTraffic?.call('out', payload['type']?.toString() ?? 'json', body);
    _channel!.sink.add(body);
    return true;
  }

  bool sendPrompt({
    required String text,
    required String agentMode,
    String? clientId,
    String? sessionId,
    bool newSession = false,
    String? replyChannel,
    bool? composerUseFast,
    List<Map<String, dynamic>>? attachments,
    TrafficCallback? onTraffic,
  }) {
    return sendJson(
      {
        'type': 'insert_text',
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'text': text,
        'prompt': true,
        'execute': true,
        'agentMode': agentMode,
        if (newSession) 'newSession': true,
        if (clientId != null) 'clientId': clientId,
        if (sessionId != null && sessionId.isNotEmpty && !newSession)
          'sessionId': sessionId,
        if (replyChannel != null && replyChannel.isNotEmpty)
          'replyChannel': replyChannel,
        if (composerUseFast != null) 'composerUseFast': composerUseFast,
        if (attachments != null && attachments.isNotEmpty)
          'attachments': attachments,
      },
      onTraffic: onTraffic,
    );
  }

  void sendStop({
    String? sessionId,
    TrafficCallback? onTraffic,
  }) {
    sendJson(
      {
        'type': 'stop_prompt',
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        if (sessionId != null && sessionId.isNotEmpty) 'sessionId': sessionId,
      },
      onTraffic: onTraffic,
    );
  }

  void sendGetSessionInfo({
    String? clientId,
    TrafficCallback? onTraffic,
  }) {
    sendJson(
      {
        'type': 'get_session_info',
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        if (clientId != null) 'clientId': clientId,
      },
      onTraffic: onTraffic,
    );
  }

  bool sendDeleteSession({
    required String sessionId,
    String? clientId,
    TrafficCallback? onTraffic,
  }) {
    return sendJson(
      {
        'type': 'delete_session',
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'sessionId': sessionId,
        if (clientId != null && clientId.isNotEmpty) 'clientId': clientId,
      },
      onTraffic: onTraffic,
    );
  }

  bool sendClearChatHistory({TrafficCallback? onTraffic}) {
    return sendJson(
      {
        'type': 'clear_chat_history',
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
      },
      onTraffic: onTraffic,
    );
  }

  void sendGetChatHistory({
    String? clientId,
    String? sessionId,
    int limit = 5,
    TrafficCallback? onTraffic,
  }) {
    sendJson(
      {
        'type': 'get_chat_history',
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        if (clientId != null) 'clientId': clientId,
        if (sessionId != null) 'sessionId': sessionId,
        'limit': limit,
      },
      onTraffic: onTraffic,
    );
  }
}
