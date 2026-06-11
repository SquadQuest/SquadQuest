import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../api/api_client.dart';

/// The result of uploading an image: the public URL to store on a resource
/// (profile.photo, community.photo, a message attachment) plus its key.
class Upload {
  const Upload({required this.key, required this.url});
  final String key;
  final String url;
}

/// Two-step image upload (specs/api/uploads.md): ask the API for a signed PUT
/// target, then PUT the bytes straight to object storage. The API never proxies
/// bytes, so the PUT uses a bare Dio (no `/v1` interceptors / auth header — the
/// signed URL carries its own auth).
abstract class UploadRepository {
  /// [kind] ∈ {profile, community, message}. Returns the stored public URL + key.
  Future<Upload> uploadImage({
    required String kind,
    required Uint8List bytes,
    required String contentType,
  });
}

class ApiUploadRepository implements UploadRepository {
  ApiUploadRepository({required this.apiClient, Dio? rawClient})
    : _raw = rawClient ?? Dio();

  final ApiClient apiClient;
  final Dio _raw;

  @override
  Future<Upload> uploadImage({
    required String kind,
    required Uint8List bytes,
    required String contentType,
  }) async {
    // 1. Signed target from our API.
    final res = await apiClient.post(
      '/v1/uploads',
      body: {'kind': kind, 'content_type': contentType},
    );
    final uploadUrl = res['upload_url'] as String;
    final publicUrl = res['public_url'] as String;
    final key = res['key'] as String;

    // 2. PUT the bytes directly to storage with the same content type.
    await _raw.put<void>(
      uploadUrl,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {
          'Content-Type': contentType,
          Headers.contentLengthHeader: bytes.length,
        },
      ),
    );

    return Upload(key: key, url: publicUrl);
  }
}
