import '../api/api_client.dart';
import '../models/profile.dart';

abstract class ProfileRepository {
  Future<Profile> me();
}

class ApiProfileRepository implements ProfileRepository {
  ApiProfileRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<Profile> me() async => Profile.fromJson(await apiClient.get('/v1/me'));
}
