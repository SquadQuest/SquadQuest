import '../api/api_client.dart';
import '../models/community.dart';

abstract class CommunityRepository {
  Future<List<Community>> discover({String? search});
  Future<Community> follow(String communityId, {required bool follow});
  Future<List<CommunityEvent>> events(String communityId);
  Future<CommunityEvent> rsvp(
    String eventId, {
    required bool going,
    required bool public,
  });
}

class ApiCommunityRepository implements CommunityRepository {
  ApiCommunityRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<List<Community>> discover({String? search}) async {
    final res = await apiClient.get(
      '/v1/communities',
      query: {'search': ?search},
    );
    return ((res['items'] as List<dynamic>?) ?? const [])
        .map((e) => Community.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Community> follow(String communityId, {required bool follow}) async {
    // Returns {you_follow, follower_count}; merge onto a thin Community for the toggle.
    final res = await apiClient.put(
      '/v1/communities/$communityId/follow',
      body: {'follow': follow},
    );
    return Community(
      id: communityId,
      name: '',
      followerCount: (res['follower_count'] as num?)?.toInt() ?? 0,
      youFollow: res['you_follow'] as bool? ?? follow,
    );
  }

  @override
  Future<List<CommunityEvent>> events(String communityId) async {
    final res = await apiClient.get('/v1/communities/$communityId/events');
    return ((res['items'] as List<dynamic>?) ?? const [])
        .map((e) => CommunityEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CommunityEvent> rsvp(
    String eventId, {
    required bool going,
    required bool public,
  }) async {
    final res = await apiClient.put(
      '/v1/community-events/$eventId/rsvp',
      body: {'going': going, 'public': public},
    );
    return CommunityEvent.fromJson(res);
  }
}
