import '../api/api_client.dart';
import '../models/message.dart';

/// Free-text messages: squad posts + thread replies (specs/api/messages.md).
abstract class MessageRepository {
  Future<Message> postSquadMessage(String squadId, String body);
  Future<List<Message>> thread(String targetType, String targetId);
  Future<Message> reply(String targetType, String targetId, String body);
}

class ApiMessageRepository implements MessageRepository {
  ApiMessageRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<Message> postSquadMessage(String squadId, String body) async {
    final res = await apiClient.post(
      '/v1/squads/$squadId/messages',
      body: {'body': body},
    );
    return Message.fromJson(res);
  }

  @override
  Future<List<Message>> thread(String targetType, String targetId) async {
    final res = await apiClient.get(
      '/v1/threads/$targetType/$targetId/messages',
    );
    return ((res['items'] as List<dynamic>?) ?? const [])
        .map((e) => Message.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Message> reply(String targetType, String targetId, String body) async {
    final res = await apiClient.post(
      '/v1/threads/$targetType/$targetId/messages',
      body: {'body': body},
    );
    return Message.fromJson(res);
  }
}
