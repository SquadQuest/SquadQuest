// Public named ctor params map to private fields; initializing formals would force
// underscore-prefixed public param names, which is worse for the API.
// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'token_store.dart';

/// One realtime event from GET /v1/stream (specs/behaviors/realtime.md): a typed,
/// id-only nudge to refetch. Unknown fields are tolerated.
class RealtimeEvent {
  const RealtimeEvent({required this.type, required this.data});
  final String type; // 'activity.created' | 'message.created' | …
  final Map<String, dynamic> data;

  String? get squadId => data['squad_id'] as String?;
  String? get threadTargetType => data['thread_target_type'] as String?;
  String? get threadTargetId => data['thread_target_id'] as String?;
}

/// Consumes the server SSE stream and emits [RealtimeEvent]s. Pure enhancement:
/// if it never connects or drops, the app still works via pull-to-refresh. The
/// stream is treated as a nudge to refetch, never the source of truth.
///
/// Uses a streamed dio GET with the bearer token (works on all platforms, unlike
/// browser EventSource which can't set headers). Reconnects with capped backoff.
class RealtimeService {
  RealtimeService({
    required String baseUrl,
    required TokenStore tokenStore,
    Dio? client,
  }) : _baseUrl = baseUrl,
       _tokens = tokenStore,
       _dio = client ?? Dio();

  final String _baseUrl;
  final TokenStore _tokens;
  final Dio _dio;

  final _events = StreamController<RealtimeEvent>.broadcast();
  Stream<RealtimeEvent> get events => _events.stream;

  bool _running = false;
  int _attempt = 0;
  CancelToken? _cancel;

  void start() {
    if (_running) return;
    _running = true;
    _connectLoop();
  }

  Future<void> stop() async {
    _running = false;
    _cancel?.cancel();
    _cancel = null;
  }

  Future<void> _connectLoop() async {
    while (_running) {
      try {
        await _connectOnce();
        _attempt = 0; // a clean end resets backoff
      } catch (_) {
        // swallow — realtime is best-effort
      }
      if (!_running) break;
      // Capped exponential backoff: 1s, 2s, 4s … max 30s.
      final delayMs = (1000 * (1 << _attempt.clamp(0, 5))).clamp(1000, 30000);
      _attempt++;
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }
  }

  Future<void> _connectOnce() async {
    final token = _tokens.accessToken;
    if (token == null) return;
    _cancel = CancelToken();

    final res = await _dio.get<ResponseBody>(
      '$_baseUrl/v1/stream',
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'text/event-stream',
        },
      ),
      cancelToken: _cancel,
    );

    final body = res.data;
    if (body == null) return;

    // Parse the SSE byte stream line-by-line, accumulating event/data per frame
    // (frames are separated by a blank line).
    var buffer = '';
    String? eventType;
    final dataLines = <String>[];

    void dispatch() {
      if (eventType != null && dataLines.isNotEmpty) {
        try {
          final json = jsonDecode(dataLines.join('\n')) as Map<String, dynamic>;
          _events.add(RealtimeEvent(type: eventType!, data: json));
        } catch (_) {
          /* ignore malformed frame */
        }
      }
      eventType = null;
      dataLines.clear();
    }

    await for (final chunk in body.stream) {
      buffer += utf8.decode(chunk, allowMalformed: true);
      var idx = buffer.indexOf('\n');
      while (idx >= 0) {
        final line = buffer.substring(0, idx).replaceAll('\r', '');
        buffer = buffer.substring(idx + 1);
        if (line.isEmpty) {
          dispatch(); // frame boundary
        } else if (line.startsWith(':')) {
          // comment / heartbeat — ignore
        } else if (line.startsWith('event:')) {
          eventType = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          dataLines.add(line.substring(5).trim());
        }
        idx = buffer.indexOf('\n');
      }
    }
  }

  void dispose() {
    stop();
    _events.close();
  }
}
