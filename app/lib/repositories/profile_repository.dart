import '../api/api_client.dart';
import '../models/profile.dart';

abstract class ProfileRepository {
  Future<Profile> me();

  /// Update own profile (onboarding name-setup + later edits). Only non-null
  /// fields are sent. See specs/api/profile.md.
  Future<Profile> updateProfile({
    String? firstName,
    String? lastName,
    String? photo,
  });
}

class ApiProfileRepository implements ProfileRepository {
  ApiProfileRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<Profile> me() async => Profile.fromJson(await apiClient.get('/v1/me'));

  @override
  Future<Profile> updateProfile({
    String? firstName,
    String? lastName,
    String? photo,
  }) async {
    final body = <String, dynamic>{
      'first_name': ?firstName,
      'last_name': ?lastName,
      'photo': ?photo,
    };
    return Profile.fromJson(await apiClient.patch('/v1/me', body: body));
  }
}
