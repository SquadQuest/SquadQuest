/// A free-text message — a squad post or a thread reply (specs/api/messages.md).
/// Attachments arrive with storage; body is non-null for now.
class Message {
  const Message({
    required this.id,
    this.senderName,
    this.senderPhoto,
    this.body,
    this.threadCount = 0,
    this.createdAt,
  });

  final String id;
  final String? senderName;
  final String? senderPhoto;
  final String? body;
  final int threadCount;
  final DateTime? createdAt;

  factory Message.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] as Map<String, dynamic>?;
    return Message(
      id: json['id'] as String,
      senderName: sender?['first_name'] as String?,
      senderPhoto: sender?['photo'] as String?,
      body: json['body'] as String?,
      threadCount: (json['thread_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'] as String),
    );
  }
}
