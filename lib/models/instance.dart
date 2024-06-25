import 'package:flutter/material.dart';
import 'package:geobase/coordinates.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:squadquest/models/user.dart';
import 'package:squadquest/models/topic.dart';

typedef InstanceID = String;
typedef InstanceMemberID = String;

enum InstanceVisibility { private, friends, public }

enum InstanceMemberStatus { invited, no, maybe, yes, omw }

Map<InstanceVisibility, Icon> visibilityIcons = {
  InstanceVisibility.private: const Icon(Icons.lock),
  InstanceVisibility.friends: const Icon(Icons.people),
  InstanceVisibility.public: const Icon(Icons.public),
};

Map<InstanceMemberStatus, Icon> rsvpIcons = {
  InstanceMemberStatus.invited: const Icon(Icons.mail),
  InstanceMemberStatus.no: const Icon(Icons.cancel),
  InstanceMemberStatus.maybe: const Icon(Icons.question_mark),
  InstanceMemberStatus.yes: const Icon(Icons.check_circle),
  InstanceMemberStatus.omw: const Icon(Icons.run_circle_outlined),
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
    required this.locationDescription,
    this.rallyPoint,
  })  : assert(
            (id != null &&
                    createdAt != null &&
                    (createdBy != null || createdById != null)) ||
                (id == null && createdAt == null && createdBy == null),
            'id, createdAt, and createdBy must be all null or all non-null'),
        assert(
            createdById == null ||
                createdBy == null ||
                createdBy.id == createdById,
            'createdBy.id and createdById must match if both are set'),
        assert(topic == null || topicId == null || topic.id == topicId,
            'topic.id and topicId must match if both are set');

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
  final String locationDescription;
  final Geographic? rallyPoint;

  LatLng? get rallyPointLatLng =>
      rallyPoint == null ? null : LatLng(rallyPoint!.lat, rallyPoint!.lon);

  factory Instance.fromMap(Map<String, dynamic> map) {
    final createdByModel = map['created_by'] is UserProfile
        ? map['created_by']
        : map['created_by'] is Map
            ? UserProfile.fromMap(map['created_by'])
            : null;

    final topicModel = map['topic'] is Topic
        ? map['topic']
        : map['topic'] is Map
            ? Topic.fromMap(map['topic'])
            : null;

    final [longitude, latitude] = map['rally_point_text'] == null
        ? [null, null]
        : map['rally_point_text']
            .substring(6, map['rally_point_text'].length - 1)
            .split(' ');

    return Instance(
        id: map['id'] as InstanceID,
        createdAt: DateTime.parse(map['created_at']).toLocal(),
        createdBy: createdByModel,
        createdById: createdByModel == null
            ? map['created_by'] as UserID
            : createdByModel.id,
        startTimeMin: DateTime.parse(map['start_time_min']).toLocal(),
        startTimeMax: DateTime.parse(map['start_time_max']).toLocal(),
        topic: topicModel,
        topicId: topicModel == null ? map['topic'] as TopicID : topicModel.id,
        title: map['title'] as String,
        visibility: InstanceVisibility.values.firstWhere(
          (e) => e.name == map['visibility'],
        ),
        locationDescription: map['location_description'] as String,
        rallyPoint: map['rally_point_text'] == null
            ? null
            : Geographic(
                lon: double.parse(longitude), lat: double.parse(latitude)));
  }

  Map<String, dynamic> toMap() {
    final data = {
      'start_time_min': startTimeMin.toUtc().toIso8601String(),
      'start_time_max': startTimeMax.toUtc().toIso8601String(),
      'topic': topic?.id ?? topicId,
      'title': title,
      'visibility': visibility.name,
      'location_description': locationDescription,
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

class InstanceMember {
  InstanceMember({
    this.id,
    this.createdAt,
    this.createdBy,
    this.createdById,
    this.instance,
    this.instanceId,
    this.member,
    this.memberId,
    required this.status,
  })  : assert(
            (id != null &&
                    createdAt != null &&
                    (createdBy != null || createdById != null)) ||
                (id == null && createdAt == null && createdBy == null),
            'id, createdAt, and createdBy must be all null or all non-null'),
        assert(
            createdById == null ||
                createdBy == null ||
                createdBy.id == createdById,
            'createdBy.id and createdById must match if both are set'),
        assert(
            instance == null || instanceId == null || instance.id == instanceId,
            'instance.id and instanceId must match if both are set'),
        assert(member == null || memberId == null || member.id == memberId,
            'member.id and memberId must match if both are set');

  final InstanceID? id;
  final DateTime? createdAt;
  final UserProfile? createdBy;
  final UserID? createdById;
  final Instance? instance;
  final InstanceID? instanceId;
  final UserProfile? member;
  final UserID? memberId;
  final InstanceMemberStatus status;

  factory InstanceMember.fromMap(Map<String, dynamic> map) {
    final createdByModel = map['created_by'] is UserProfile
        ? map['created_by']
        : map['created_by'] is Map
            ? UserProfile.fromMap(map['created_by'])
            : null;
    final instanceModel = map['instance'] is Instance
        ? map['instance']
        : map['instance'] is Map
            ? Instance.fromMap(map['instance'])
            : null;
    final memberModel = map['member'] is UserProfile
        ? map['member']
        : map['member'] is Map
            ? UserProfile.fromMap(map['member'])
            : null;

    return InstanceMember(
      id: map['id'] as InstanceMemberID,
      createdAt: DateTime.parse(map['created_at']).toLocal(),
      createdBy: createdByModel,
      createdById: createdByModel == null
          ? map['created_by'] as UserID
          : createdByModel.id,
      instance: instanceModel,
      instanceId: instanceModel == null
          ? map['instance'] as InstanceID
          : instanceModel.id,
      member: memberModel,
      memberId: memberModel == null ? map['member'] as UserID : memberModel.id,
      status: InstanceMemberStatus.values.firstWhere(
        (e) => e.name == map['status'],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    final data = {
      'instance': instance?.id ?? instanceId,
      'member': member?.id ?? memberId,
      'status': status.name,
    };

    if (id != null) {
      data['id'] = id!;
    }

    return data;
  }

  @override
  String toString() {
    return 'InstanceMember{instance: $instanceId, member: $memberId, status: $status}';
  }
}
