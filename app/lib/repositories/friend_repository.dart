import '../api/api_client.dart';
import '../models/friend.dart';

abstract class FriendRepository {
  /// The caller's accepted friends.
  Future<List<Friend>> list();

  /// Pending connection requests involving the caller (incoming + outgoing).
  Future<FriendRequests> requests();

  /// Send a request by phone. Returns the resulting status:
  /// `'requested'` or `'accepted'` (reciprocal/idempotent). See specs/api/friends.md.
  Future<String> sendRequest(String phone);

  /// Accept/decline an incoming request (requestee only).
  Future<void> respond(String requestId, {required bool accept});
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

  @override
  Future<FriendRequests> requests() async =>
      FriendRequests.fromJson(await apiClient.get('/v1/friends/requests'));

  @override
  Future<String> sendRequest(String phone) async {
    final res = await apiClient.post(
      '/v1/friends/requests',
      body: {'phone': phone},
    );
    return res['status'] as String? ?? 'requested';
  }

  @override
  Future<void> respond(String requestId, {required bool accept}) async {
    await apiClient.put(
      '/v1/friends/requests/$requestId',
      body: {'accept': accept},
    );
  }
}
