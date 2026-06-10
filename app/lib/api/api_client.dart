import 'package:dio/dio.dart';

import '../repositories/token_store.dart';
import 'api_exception.dart';

/// Typed transport for the versioned `/v1` API (specs/api/conventions.md).
///
/// One dio instance with interceptors that: stamp the required client-build
/// header, inject the bearer access token, single-flight a 401 → /v1/auth/refresh
/// → retry, and translate the error envelope into [ApiException]. On unrecoverable
/// auth failure it calls [onAuthFailure] so the app can sign out.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required TokenStore tokenStore,
    required String clientHeader,
    this._onAuthFailure,
  }) : _tokens = tokenStore,
       _dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           headers: {'X-SquadQuest-Client': clientHeader},
           validateStatus: (s) => s != null && s < 500,
         ),
       ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _tokens.accessToken;
          if (token != null && options.extra['skipAuth'] != true) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final TokenStore _tokens;
  final Future<void> Function()? _onAuthFailure;
  Future<bool>? _refreshing; // single-flight guard

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) => _send(() => _dio.get(path, queryParameters: query));

  Future<Map<String, dynamic>> post(String path, {Object? body}) =>
      _send(() => _dio.post(path, data: body));

  Future<Map<String, dynamic>> put(String path, {Object? body}) =>
      _send(() => _dio.put(path, data: body));

  Future<Map<String, dynamic>> patch(String path, {Object? body}) =>
      _send(() => _dio.patch(path, data: body));

  Future<Map<String, dynamic>> delete(String path, {Object? body}) =>
      _send(() => _dio.delete(path, data: body));

  // Issues the request, retrying once after a successful token refresh on 401.
  Future<Map<String, dynamic>> _send(
    Future<Response<dynamic>> Function() request, {
    bool isRetry = false,
  }) async {
    final res = await request();
    if (res.statusCode == 401 && !isRetry && _tokens.refreshToken != null) {
      if (await _refresh()) return _send(request, isRetry: true);
    }
    return _unwrap(res);
  }

  Map<String, dynamic> _unwrap(Response<dynamic> res) {
    final status = res.statusCode ?? 0;
    final data = res.data;
    if (status >= 200 && status < 300) {
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    }
    final err =
        (data is Map<String, dynamic> ? data['error'] : null)
            as Map<String, dynamic>?;
    throw ApiException(
      statusCode: status,
      code: err?['code'] as String? ?? 'unknown',
      message: err?['message'] as String? ?? 'Request failed',
      upgradeRequired: status == 426,
    );
  }

  Future<bool> _refresh() =>
      _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<bool> _doRefresh() async {
    try {
      final res = await _dio.post(
        '/v1/auth/refresh',
        data: {'refresh_token': _tokens.refreshToken},
        options: Options(extra: {'skipAuth': true}),
      );
      if (res.statusCode == 200 && res.data is Map) {
        final d = res.data as Map<String, dynamic>;
        await _tokens.save(
          access: d['access_token'] as String,
          refresh: d['refresh_token'] as String,
        );
        return true;
      }
    } catch (_) {
      // fall through to failure
    }
    await _tokens.clear();
    await _onAuthFailure?.call();
    return false;
  }
}
