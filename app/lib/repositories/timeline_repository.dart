import '../api/api_client.dart';
import '../models/activity.dart';
import '../models/feed_item.dart';

class TimelinePage {
  const TimelinePage({required this.items, this.nextCursor});
  final List<Activity> items;
  final String? nextCursor;
}

/// A heterogeneous squad feed page (activities + messages).
class SquadFeedPage {
  const SquadFeedPage({required this.items, this.nextCursor});
  final List<FeedItem> items;
  final String? nextCursor;
}

abstract class TimelineRepository {
  Future<TimelinePage> friends({int limit, String? before});
  Future<SquadFeedPage> squadFeed(String squadId, {int limit, String? before});
}

class ApiTimelineRepository implements TimelineRepository {
  ApiTimelineRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<TimelinePage> friends({int limit = 50, String? before}) async {
    final res = await apiClient.get(
      '/v1/timeline/friends',
      query: {'limit': limit, 'before': ?before},
    );
    final items = ((res['items'] as List<dynamic>?) ?? const [])
        .map((e) => Activity.fromJson(e as Map<String, dynamic>))
        .toList();
    return TimelinePage(
      items: items,
      nextCursor: res['next_cursor'] as String?,
    );
  }

  @override
  Future<SquadFeedPage> squadFeed(
    String squadId, {
    int limit = 50,
    String? before,
  }) async {
    final res = await apiClient.get(
      '/v1/squads/$squadId/timeline',
      query: {'limit': limit, 'before': ?before},
    );
    final items = ((res['items'] as List<dynamic>?) ?? const [])
        .map((e) => FeedItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return SquadFeedPage(
      items: items,
      nextCursor: res['next_cursor'] as String?,
    );
  }
}
