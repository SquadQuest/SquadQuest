import '../api/api_client.dart';
import '../models/friend.dart';

abstract class FriendRepository {
  Future<List<Friend>> list();
}

class ApiFriendRepository implements FriendRepository {
  ApiFriendRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<List<Friend>> list() async {
    final res = await apiClient.get('/v1/friends');
    return ((res['items'] as List<dynamic>?) ?? const [])
        .map((e) => Friend.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
