import '../api/api_client.dart';
import '../models/activity.dart';

/// Write actions on ideas/activities (specs/api/ideas-activities.md). Every action
/// returns the updated [Activity] (the API re-serializes it), so callers can refresh
/// without a separate read. Friends/all_friends audience only this stage.
abstract class ActivityRepository {
  /// Create an idea. Friends scope (default) → all_friends audience; squad scope →
  /// pass [squadId] (visible to that squad's members).
  Future<Activity> createIdea({
    required String activityTypeId,
    bool allowSuggestions,
    List<String> timeOptions,
    List<String> locationOptions,
    String? squadId,
    String? communityEventId,
  });

  Future<Activity> setResponse(String activityId, String value);
  Future<Activity> clearResponse(String activityId);
  Future<Activity> vote(
    String activityId,
    String optionId, {
    required bool voted,
  });
  Future<Activity> addOption(String activityId, String kind, String label);
  Future<Activity> confirm(
    String activityId, {
    String? timeOptionId,
    String? locationOptionId,
  });
}

class ApiActivityRepository implements ActivityRepository {
  ApiActivityRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<Activity> createIdea({
    required String activityTypeId,
    bool allowSuggestions = false,
    List<String> timeOptions = const [],
    List<String> locationOptions = const [],
    String? squadId,
    String? communityEventId,
  }) async {
    final res = await apiClient.post(
      '/v1/ideas',
      body: {
        'activity_type_id': activityTypeId,
        if (squadId != null) 'scope': 'squad',
        'squad_id': ?squadId,
        'community_event_id': ?communityEventId,
        'audience': {'kind': 'all_friends'},
        'allow_suggestions': allowSuggestions,
        if (timeOptions.isNotEmpty) 'time_options': timeOptions,
        if (locationOptions.isNotEmpty) 'location_options': locationOptions,
      },
    );
    return Activity.fromJson(res);
  }

  @override
  Future<Activity> setResponse(String activityId, String value) async {
    final res = await apiClient.put(
      '/v1/ideas/$activityId/response',
      body: {'value': value},
    );
    return Activity.fromJson(res);
  }

  @override
  Future<Activity> clearResponse(String activityId) async {
    final res = await apiClient.delete('/v1/ideas/$activityId/response');
    return Activity.fromJson(res);
  }

  @override
  Future<Activity> vote(
    String activityId,
    String optionId, {
    required bool voted,
  }) async {
    final res = await apiClient.put(
      '/v1/ideas/$activityId/votes',
      body: {'option_id': optionId, 'voted': voted},
    );
    return Activity.fromJson(res);
  }

  @override
  Future<Activity> addOption(
    String activityId,
    String kind,
    String label,
  ) async {
    final res = await apiClient.post(
      '/v1/ideas/$activityId/options',
      body: {'kind': kind, 'label': label},
    );
    return Activity.fromJson(res);
  }

  @override
  Future<Activity> confirm(
    String activityId, {
    String? timeOptionId,
    String? locationOptionId,
  }) async {
    final res = await apiClient.post(
      '/v1/ideas/$activityId/confirm',
      body: {
        'time_option_id': ?timeOptionId,
        'location_option_id': ?locationOptionId,
      },
    );
    return Activity.fromJson(res);
  }
}
