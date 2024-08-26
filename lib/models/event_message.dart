import 'package:squadquest/logger.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/user.dart';

typedef EventMessageID = String;

class EventMessage {
  final EventMessageID id;
  final DateTime createdAt;
  final UserProfile? createdBy;
  final UserID? createdById;
  final InstanceID event;
  final String content;
  final bool pinned;

  EventMessage({
    required this.id,
    required this.createdAt,
    required this.createdBy,
    this.createdById,
    required this.event,
    required this.content,
    required this.pinned,
  });

  factory EventMessage.fromMap(Map<String, dynamic> map) {
    final createdByModel = map['created_by'] is UserProfile
        ? map['created_by']
        : map['created_by'] is Map
            ? UserProfile.fromMap(map['created_by'])
            : null;

    logger.d({'EventMessage.fromMap': map});
    return EventMessage(
      id: map['id'] as EventMessageID,
      createdAt: DateTime.parse(map['created_at']).toLocal(),
      createdBy: createdByModel,
      createdById: createdByModel == null
          ? map['created_by'] as UserID?
          : createdByModel.id,
      event: map['instance'] as InstanceID,
      content: map['content'],
      pinned: map['pinned'] as bool,
    );
  }

  @override
  String toString() {
    return 'EventMessage{id: $id, event: $event, content: $content}';
  }
}
