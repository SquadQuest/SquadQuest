import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadquest/repositories/realtime_service.dart';
import 'package:squadquest/repositories/token_store.dart';

/// A TokenStore with a preset access token, no platform keychain.
class _FakeTokenStore extends TokenStore {
  _FakeTokenStore() {
    accessToken = 'tok';
  }
  @override
  Future<void> load() async {}
}

/// A dio HttpClientAdapter that streams the given SSE chunks as the response body.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._chunks);
  final List<String> _chunks;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final stream = Stream<Uint8List>.fromIterable(
      _chunks.map((c) => Uint8List.fromList(utf8.encode(c))),
    );
    return ResponseBody(
      stream,
      200,
      headers: {
        Headers.contentTypeHeader: ['text/event-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _fakeDio(List<String> chunks) =>
    Dio()..httpClientAdapter = _FakeAdapter(chunks);

void main() {
  test(
    'parses SSE frames into typed events; ignores heartbeats + junk',
    () async {
      final svc = RealtimeService(
        baseUrl: 'http://test',
        tokenStore: _FakeTokenStore(),
        client: _fakeDio([
          ': connected\n\n',
          'event: activity.created\n',
          'data: {"id":"a1","scope":"friends"}\n\n',
          ': ping\n\n',
          // a frame split across chunks
          'event: message.created\n',
          'data: {"id":"m1",',
          '"squad_id":"s1"}\n\n',
          // malformed data — must be ignored, not crash
          'event: message.created\n',
          'data: not json{\n\n',
        ]),
      );

      final received = <RealtimeEvent>[];
      final sub = svc.events.listen(received.add);
      svc.start();

      // Let the stream drain + dispatch.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await svc.stop();
      await sub.cancel();

      expect(received.length, 2);
      expect(received[0].type, 'activity.created');
      expect(received[0].data['id'], 'a1');
      expect(received[1].type, 'message.created');
      expect(received[1].squadId, 's1');
    },
  );
}
