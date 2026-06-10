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

  // ── Leader tooling (specs/api/communities.md) ─────────────────────────────

  /// Create a community; the caller becomes its first leader.
  Future<Community> create({
    required String name,
    String? tagline,
    String? icon,
    String? color,
  });

  /// Edit a community (leader-only). Only non-null fields are sent.
  Future<Community> update(
    String communityId, {
    String? name,
    String? tagline,
    String? icon,
    String? color,
  });

  /// Post an event to a community (leader-only).
  Future<CommunityEvent> createEvent(
    String communityId, {
    required String title,
    String? time,
    String? recurrence,
    String? location,
  });

  /// Edit an event (leader-only). Only non-null fields are sent.
  Future<CommunityEvent> updateEvent(
    String eventId, {
    String? title,
    String? time,
    String? recurrence,
    String? location,
  });

  /// Cancel an event (leader-only).
  Future<void> deleteEvent(String eventId);
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

  @override
  Future<Community> create({
    required String name,
    String? tagline,
    String? icon,
    String? color,
  }) async {
    final res = await apiClient.post(
      '/v1/communities',
      body: {'name': name, 'tagline': ?tagline, 'icon': ?icon, 'color': ?color},
    );
    return Community.fromJson(res);
  }

  @override
  Future<Community> update(
    String communityId, {
    String? name,
    String? tagline,
    String? icon,
    String? color,
  }) async {
    final res = await apiClient.patch(
      '/v1/communities/$communityId',
      body: {
        'name': ?name,
        'tagline': ?tagline,
        'icon': ?icon,
        'color': ?color,
      },
    );
    return Community.fromJson(res);
  }

  @override
  Future<CommunityEvent> createEvent(
    String communityId, {
    required String title,
    String? time,
    String? recurrence,
    String? location,
  }) async {
    final res = await apiClient.post(
      '/v1/communities/$communityId/events',
      body: {
        'title': title,
        'time': ?time,
        'recurrence': ?recurrence,
        'location': ?location,
      },
    );
    return CommunityEvent.fromJson(res);
  }

  @override
  Future<CommunityEvent> updateEvent(
    String eventId, {
    String? title,
    String? time,
    String? recurrence,
    String? location,
  }) async {
    final res = await apiClient.patch(
      '/v1/community-events/$eventId',
      body: {
        'title': ?title,
        'time': ?time,
        'recurrence': ?recurrence,
        'location': ?location,
      },
    );
    return CommunityEvent.fromJson(res);
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    await apiClient.delete('/v1/community-events/$eventId');
  }
}
