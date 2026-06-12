import '../api/api_client.dart';
import '../models/message.dart';

/// Free-text + photo messages: squad posts + thread replies (specs/api/messages.md).
/// Attachments come from POST /v1/uploads (kind `message`); a message needs body or
/// at least one attachment.
abstract class MessageRepository {
  Future<Message> postSquadMessage(
    String squadId,
    String body, {
    List<MessageAttachment> attachments,
  });
  Future<List<Message>> thread(String targetType, String targetId);
  Future<Message> reply(
    String targetType,
    String targetId,
    String body, {
    List<MessageAttachment> attachments,
  });
}

class ApiMessageRepository implements MessageRepository {
  ApiMessageRepository({required this.apiClient});

  final ApiClient apiClient;

  Map<String, dynamic> _body(
    String body,
    List<MessageAttachment> attachments,
  ) => {
    if (body.isNotEmpty) 'body': body,
    if (attachments.isNotEmpty)
      'attachments': attachments.map((a) => a.toJson()).toList(),
  };

  @override
  Future<Message> postSquadMessage(
    String squadId,
    String body, {
    List<MessageAttachment> attachments = const [],
  }) async {
    final res = await apiClient.post(
      '/v1/squads/$squadId/messages',
      body: _body(body, attachments),
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
  Future<Message> reply(
    String targetType,
    String targetId,
    String body, {
    List<MessageAttachment> attachments = const [],
  }) async {
    final res = await apiClient.post(
      '/v1/threads/$targetType/$targetId/messages',
      body: _body(body, attachments),
    );
    return Message.fromJson(res);
  }
}
