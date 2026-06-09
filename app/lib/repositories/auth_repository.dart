import '../api/api_client.dart';
import '../models/profile.dart';
import 'token_store.dart';

/// Phone-OTP auth against /v1/auth (specs/api/auth.md).
abstract class AuthRepository {
  Future<void> requestOtp(String phone);

  /// Verify the code → persist tokens → return (profile, claimedV1).
  Future<({Profile profile, bool claimedV1})> verifyOtp(
    String phone,
    String code,
  );

  Future<void> logout();
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({required this.apiClient, required this.tokens});

  final ApiClient apiClient;
  final TokenStore tokens;

  @override
  Future<void> requestOtp(String phone) async {
    await apiClient.post('/v1/auth/otp/request', body: {'phone': phone});
  }

  @override
  Future<({Profile profile, bool claimedV1})> verifyOtp(
    String phone,
    String code,
  ) async {
    final res = await apiClient.post(
      '/v1/auth/otp/verify',
      body: {'phone': phone, 'code': code},
    );
    await tokens.save(
      access: res['access_token'] as String,
      refresh: res['refresh_token'] as String,
    );
    return (
      profile: Profile.fromJson(res['profile'] as Map<String, dynamic>),
      claimedV1: res['claimed_v1'] as bool? ?? false,
    );
  }

  @override
  Future<void> logout() async {
    final refresh = tokens.refreshToken;
    if (refresh != null) {
      try {
        await apiClient.post(
          '/v1/auth/logout',
          body: {'refresh_token': refresh},
        );
      } catch (_) {
        // best-effort; clear locally regardless
      }
    }
    await tokens.clear();
  }
}
