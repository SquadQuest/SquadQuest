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

  /// Accept an incoming request (requestee only). There is no decline — see [ignore].
  Future<void> accept(String requestId);

  /// Ignore / un-ignore an incoming request. Silent (the sender still sees pending)
  /// and recoverable from the Ignored surface. See the dismissal-is-silent principle.
  Future<void> ignore(String requestId);
  Future<void> unignore(String requestId);

  /// The caller's ignored incoming items (friend requests + want invites), by type.
  Future<List<IgnoredItem>> ignored();
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
  Future<void> accept(String requestId) async {
    await apiClient.put(
      '/v1/friends/requests/$requestId',
      body: {'accept': true},
    );
  }

  @override
  Future<void> ignore(String requestId) async =>
      apiClient.post('/v1/friends/requests/$requestId/ignore');

  @override
  Future<void> unignore(String requestId) async =>
      apiClient.post('/v1/friends/requests/$requestId/unignore');

  @override
  Future<List<IgnoredItem>> ignored() async {
    final res = await apiClient.get('/v1/ignored');
    return ((res['items'] as List<dynamic>?) ?? const [])
        .map((e) => IgnoredItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
