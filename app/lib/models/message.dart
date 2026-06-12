/// A free-text + photo message — a squad post or a thread reply
/// (specs/api/messages.md). body is nullable (photo-only allowed).
class Message {
  const Message({
    required this.id,
    this.senderName,
    this.senderPhoto,
    this.body,
    this.attachments = const [],
    this.threadCount = 0,
    this.createdAt,
  });

  final String id;
  final String? senderName;
  final String? senderPhoto;
  final String? body;
  final List<MessageAttachment> attachments;
  final int threadCount;
  final DateTime? createdAt;

  factory Message.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] as Map<String, dynamic>?;
    return Message(
      id: json['id'] as String,
      senderName: sender?['first_name'] as String?,
      senderPhoto: sender?['photo'] as String?,
      body: json['body'] as String?,
      attachments: ((json['attachments'] as List<dynamic>?) ?? const [])
          .map((e) => MessageAttachment.fromJson(e as Map<String, dynamic>))
          .toList(),
      threadCount: (json['thread_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'] as String),
    );
  }
}

/// An image attachment on a message: storage key + public URL (specs/api/uploads.md).
class MessageAttachment {
  const MessageAttachment({required this.key, required this.url});

  final String key;
  final String url;

  factory MessageAttachment.fromJson(Map<String, dynamic> json) =>
      MessageAttachment(
        key: json['key'] as String? ?? '',
        url: json['url'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'key': key, 'url': url};
}
