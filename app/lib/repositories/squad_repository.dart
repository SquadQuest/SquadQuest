import '../api/api_client.dart';
import '../models/squad.dart';

abstract class SquadRepository {
  Future<List<Squad>> list();
  Future<SquadDetail> create(String name, List<String> memberIds);
  Future<SquadDetail> get(String squadId);
  Future<SquadDetail> addMember(String squadId, String profileId);
}

class ApiSquadRepository implements SquadRepository {
  ApiSquadRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<List<Squad>> list() async {
    final res = await apiClient.get('/v1/squads');
    return ((res['items'] as List<dynamic>?) ?? const [])
        .map((e) => Squad.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<SquadDetail> create(String name, List<String> memberIds) async {
    final res = await apiClient.post(
      '/v1/squads',
      body: {'name': name, 'member_ids': memberIds},
    );
    return SquadDetail.fromJson(res);
  }

  @override
  Future<SquadDetail> get(String squadId) async =>
      SquadDetail.fromJson(await apiClient.get('/v1/squads/$squadId'));

  @override
  Future<SquadDetail> addMember(String squadId, String profileId) async {
    final res = await apiClient.post(
      '/v1/squads/$squadId/members',
      body: {'profile_id': profileId},
    );
    return SquadDetail.fromJson(res);
  }
}
