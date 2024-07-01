import 'package:squadquest/models/user.dart';
import 'package:squadquest/models/topic.dart';

class TopicMember {
  TopicMember({
    this.topic,
    this.topicId,
    this.member,
    this.memberId,
    this.createdAt,
  });

  final Topic? topic;
  final TopicID? topicId;
  final UserProfile? member;
  final UserID? memberId;
  final DateTime? createdAt;

  factory TopicMember.fromMap(Map<String, dynamic> map) {
    final topicModel = map['topic'] is Topic
        ? map['topic']
        : map['topic'] is Map
            ? Topic.fromMap(map['topic'])
            : null;

    final memberModel = map['member'] is UserProfile
        ? map['member']
        : map['member'] is Map
            ? UserProfile.fromMap(map['member'])
            : null;

    return TopicMember(
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at']).toLocal()
          : null,
      topic: topicModel,
      topicId: topicModel == null ? map['topic'] as UserID : topicModel.id,
      member: memberModel,
      memberId: memberModel == null ? map['member'] as UserID : memberModel.id,
    );
  }

  Map<String, dynamic> toMap() {
    final data = {
      'topic': topic?.id ?? topicId,
      'member': member?.id ?? memberId,
    };

    return data;
  }

  @override
  String toString() {
    return 'TopicMember{topic: $topic, member: $member}';
  }
}

class MyTopicMembership {
  MyTopicMembership({
    required this.topic,
    required this.subscribed,
    required this.events,
  });

  final Topic topic;
  final bool subscribed;
  final int? events;

  factory MyTopicMembership.fromMap(Map<String, dynamic> map) {
    final topicModel = map['topic'] is Topic
        ? map['topic']
        : map['topic'] is Map
            ? Topic.fromMap(map['topic'])
            : null;

    return MyTopicMembership(
      topic: topicModel,
      subscribed: map['subscribed'],
      events: map['events'],
    );
  }

  @override
  String toString() {
    return 'TopicMember{topic: $topic, subscribed: $subscribed, events: $events}';
  }
}
