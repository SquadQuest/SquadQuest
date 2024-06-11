import 'package:flutter/material.dart';
import 'package:squad_quest/models/user.dart';
import 'package:squad_quest/models/topic.dart';

typedef InstanceID = String;

enum InstanceVisibility { private, friends, public }

Map<InstanceVisibility, Icon> visibilityIcons = {
  InstanceVisibility.private: const Icon(Icons.lock),
  InstanceVisibility.friends: const Icon(Icons.people),
  InstanceVisibility.public: const Icon(Icons.public),
};

class Instance {
  Instance({
    this.id,
    this.createdAt,
    this.createdBy,
    this.createdById,
    required this.startTimeMin,
    required this.startTimeMax,
    this.topic,
    this.topicId,
    required this.title,
    required this.visibility,
  });

  final InstanceID? id;
  final DateTime? createdAt;
  final UserProfile? createdBy;
  final UserID? createdById;
  final DateTime startTimeMin;
  final DateTime startTimeMax;
  final Topic? topic;
  final TopicID? topicId;
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

  Map<String, dynamic> toMap() {
    final data = {
      'start_time_min': startTimeMin.toIso8601String(),
      'start_time_max': startTimeMax.toIso8601String(),
      'topic': topic?.id ?? topicId,
      'title': title,
      'visibility': visibility.name,
    };

    if (id != null) {
      data['id'] = id!;
    }

    return data;
  }

  @override
  String toString() {
    return 'Instance{id: $id, title: $title}';
  }
}
