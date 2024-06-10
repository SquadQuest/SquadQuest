import 'package:squad_quest/models/user.dart';
import 'package:squad_quest/models/topic.dart';

typedef InstanceID = String;

enum InstanceVisibility { private, friends, public }

class Instance {
  Instance({
    required this.id,
    required this.createdAt,
    this.createdBy,
    required this.createdById,
    required this.startTimeMin,
    required this.startTimeMax,
    this.topic,
    required this.topicId,
    required this.title,
    required this.visibility,
  });

  final InstanceID id;
  final DateTime createdAt;
  final UserProfile? createdBy;
  final UserID createdById;
  final DateTime startTimeMin;
  final DateTime startTimeMax;
  final Topic? topic;
  final TopicID topicId;
  final String title;
  final InstanceVisibility visibility;

  factory Instance.fromMap(Map<String, dynamic> map) {
    final createdByModel = map['created_by'] is Map
        ? UserProfile.fromMap(map['created_by'])
        : null;

    final topicModel = map['topic'] is Map ? Topic.fromMap(map['topic']) : null;

    return Instance(
      id: map['id'] as InstanceID,
      createdAt: DateTime.parse(map['created_at']),
      createdBy: createdByModel,
      createdById: createdByModel == null
          ? map['created_by'] as UserID
          : createdByModel.id,
      startTimeMin: DateTime.parse(map['start_time_min']),
      startTimeMax: DateTime.parse(map['start_time_max']),
      topic: topicModel,
      topicId: topicModel == null ? map['topic'] as TopicID : topicModel.id,
      title: map['title'] as String,
      visibility: InstanceVisibility.values.firstWhere(
        (e) => e.name == map['visibility'],
      ),
    );
  }

  // Map<String, dynamic> toMap() {
  // ...
  // }
}
