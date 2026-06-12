import '../api/api_client.dart';
import '../models/activity.dart';
import '../models/want.dart';

/// Wants: a shared backlog of pre-activities (specs/api/wants.md). CRUD + invite +
/// respond + ignore + promote. Mutating actions return the updated [Want] (the API
/// re-serializes it) so callers refresh without a separate read; promote returns the
/// spawned [Activity].
abstract class WantRepository {
  Future<List<Want>> listOwn({bool includeArchived = false});
  Future<List<Want>> listInvited();

  Future<Want> create({
    required String activityTypeId,
    String? title,
    String? location,
    String? notes,
    String kind,
    List<String> inviteeIds,
  });
  Future<Want> update(
    String id, {
    String? activityTypeId,
    String? title,
    String? location,
    String? notes,
    String? kind,
  });
  Future<void> delete(String id);

  Future<Want> invite(String id, List<String> profileIds);
  Future<Want> uninvite(String id, String profileId);

  Future<Want> respond(String id, String value);
  Future<Want> clearResponse(String id);
  Future<void> ignore(String id);
  Future<void> unignore(String id);

  /// Promote = spawn an idea. [audiencePersonIds] null → server defaults to the
  /// want's invitees. Returns the new activity.
  Future<Activity> promote(
    String id, {
    List<String>? audiencePersonIds,
    List<String> timeOptions,
    List<String> locationOptions,
    bool allowSuggestions,
    String? squadId,
  });
}

class ApiWantRepository implements WantRepository {
  ApiWantRepository({required this.apiClient});

  final ApiClient apiClient;

  List<Want> _list(Map<String, dynamic> res) =>
      ((res['items'] as List<dynamic>?) ?? const [])
          .map((e) => Want.fromJson(e as Map<String, dynamic>))
          .toList();

  @override
  Future<List<Want>> listOwn({bool includeArchived = false}) async => _list(
    await apiClient.get(
      '/v1/wants${includeArchived ? '?include_archived=true' : ''}',
    ),
  );

  @override
  Future<List<Want>> listInvited() async =>
      _list(await apiClient.get('/v1/wants/invited'));

  @override
  Future<Want> create({
    required String activityTypeId,
    String? title,
    String? location,
    String? notes,
    String kind = 'one_shot',
    List<String> inviteeIds = const [],
  }) async {
    final res = await apiClient.post(
      '/v1/wants',
      body: {
        'activity_type_id': activityTypeId,
        'title': ?title,
        'location': ?location,
        'notes': ?notes,
        'kind': kind,
        if (inviteeIds.isNotEmpty) 'invitee_ids': inviteeIds,
      },
    );
    return Want.fromJson(res);
  }

  @override
  Future<Want> update(
    String id, {
    String? activityTypeId,
    String? title,
    String? location,
    String? notes,
    String? kind,
  }) async {
    final res = await apiClient.patch(
      '/v1/wants/$id',
      body: {
        'activity_type_id': ?activityTypeId,
        'title': ?title,
        'location': ?location,
        'notes': ?notes,
        'kind': ?kind,
      },
    );
    return Want.fromJson(res);
  }

  @override
  Future<void> delete(String id) async => apiClient.delete('/v1/wants/$id');

  @override
  Future<Want> invite(String id, List<String> profileIds) async {
    final res = await apiClient.post(
      '/v1/wants/$id/invites',
      body: {'profile_ids': profileIds},
    );
    return Want.fromJson(res);
  }

  @override
  Future<Want> uninvite(String id, String profileId) async {
    final res = await apiClient.delete('/v1/wants/$id/invites/$profileId');
    return Want.fromJson(res);
  }

  @override
  Future<Want> respond(String id, String value) async {
    final res = await apiClient.put(
      '/v1/wants/$id/response',
      body: {'value': value},
    );
    return Want.fromJson(res);
  }

  @override
  Future<Want> clearResponse(String id) async {
    final res = await apiClient.delete('/v1/wants/$id/response');
    return Want.fromJson(res);
  }

  @override
  Future<void> ignore(String id) async =>
      apiClient.post('/v1/wants/$id/ignore');

  @override
  Future<void> unignore(String id) async =>
      apiClient.post('/v1/wants/$id/unignore');

  @override
  Future<Activity> promote(
    String id, {
    List<String>? audiencePersonIds,
    List<String> timeOptions = const [],
    List<String> locationOptions = const [],
    bool allowSuggestions = false,
    String? squadId,
  }) async {
    final res = await apiClient.post(
      '/v1/wants/$id/promote',
      body: {
        if (squadId != null) 'scope': 'squad',
        'squad_id': ?squadId,
        if (audiencePersonIds != null)
          'audience': {'kind': 'people', 'person_ids': audiencePersonIds},
        'allow_suggestions': allowSuggestions,
        if (timeOptions.isNotEmpty) 'time_options': timeOptions,
        if (locationOptions.isNotEmpty) 'location_options': locationOptions,
      },
    );
    return Activity.fromJson(res);
  }
}
