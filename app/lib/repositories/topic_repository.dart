import '../api/api_client.dart';
import '../models/topic.dart';

abstract class TopicRepository {
  Future<List<Topic>> list();
}

class ApiTopicRepository implements TopicRepository {
  ApiTopicRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<List<Topic>> list() async {
    final res = await apiClient.get('/v1/topics');
    return ((res['items'] as List<dynamic>?) ?? const [])
        .map((e) => Topic.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
