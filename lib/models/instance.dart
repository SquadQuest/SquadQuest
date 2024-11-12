import 'package:flutter/material.dart';
import 'package:geobase/coordinates.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:open_location_code/open_location_code.dart' as pluscode;

import 'package:squadquest/common.dart';
import 'package:squadquest/models/user.dart';
import 'package:squadquest/models/topic.dart';

typedef InstanceID = String;
typedef InstanceMemberID = String;

enum InstanceVisibility { private, friends, public }

enum InstanceStatus { draft, live, canceled }

enum InstanceMemberStatus { invited, no, maybe, yes, omw }

enum InstanceTimeGroup { current, upcoming, past }

Map<InstanceVisibility, Icon> visibilityIcons = {
  InstanceVisibility.private: const Icon(Icons.lock),
  InstanceVisibility.friends: const Icon(Icons.people),
  InstanceVisibility.public: const Icon(Icons.public),
};

Map<InstanceStatus, Icon> statusIcons = {
  InstanceStatus.canceled: const Icon(Icons.cancel_outlined),
};

Map<InstanceMemberStatus, Icon> rsvpIcons = {
  InstanceMemberStatus.invited: const Icon(Icons.mail),
  InstanceMemberStatus.no: const Icon(Icons.cancel),
  InstanceMemberStatus.maybe: const Icon(Icons.question_mark),
  InstanceMemberStatus.yes: const Icon(Icons.check_circle),
  InstanceMemberStatus.omw: const Icon(Icons.run_circle_outlined),
};

/// Base class for all instances
abstract class Instance implements Hydratable {
  Instance({
    required this.startTimeMin,
    required this.startTimeMax,
    this.endTime,
    this.topic,
    this.topicId,
    required this.title,
    required this.visibility,
    required this.locationDescription,
    this.rallyPoint,
    this.link,
    this.notes,
    this.bannerPhoto,
  }) : assert(topic == null || topicId == null || topic.id == topicId,
            'topic.id and topicId must match if both are set');

  final DateTime startTimeMin;
  final DateTime startTimeMax;
  final DateTime? endTime;
  final Topic? topic;
  final TopicID? topicId;
  final String title;
  final InstanceVisibility visibility;
  final String locationDescription;
  final Geographic? rallyPoint;
  final Uri? link;
  final String? notes;
  final Uri? bannerPhoto;

  LatLng? get rallyPointLatLng =>
      rallyPoint == null ? null : LatLng(rallyPoint!.lat, rallyPoint!.lon);

  String? get rallyPointPlusCode => rallyPoint == null
      ? null
      : pluscode.PlusCode.encode(
              pluscode.LatLng(rallyPoint!.lat, rallyPoint!.lon))
          .toString();

  InstanceTimeGroup getTimeGroup([DateTime? now]) {
    now ??= DateTime.now();

    if (startTimeMin.isAfter(now)) {
      return InstanceTimeGroup.upcoming;
    }

    if ((endTime != null && endTime!.isBefore(now)) ||
        startTimeMax.isBefore(now.subtract(const Duration(hours: 12)))) {
      return InstanceTimeGroup.past;
    }

    return InstanceTimeGroup.current;
  }

  @override
  String toString() {
    return 'Instance{title: $title}';
  }
}

/// Represents a draft instance being created
class DraftInstance extends Instance {
  DraftInstance({
    required super.startTimeMin,
    required super.startTimeMax,
    super.endTime,
    super.topic,
    super.topicId,
    required super.title,
    required super.visibility,
    required super.locationDescription,
    super.rallyPoint,
    super.link,
    super.notes,
    super.bannerPhoto,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'status': InstanceStatus.live.name,
      'start_time_min': startTimeMin.toUtc().toIso8601String(),
      'start_time_max': startTimeMax.toUtc().toIso8601String(),
      'end_time': endTime?.toUtc().toIso8601String(),
      'topic': topic?.id ?? topicId,
      'title': title,
      'visibility': visibility.name,
      'location_description': locationDescription,
      'rally_point': rallyPoint == null
          ? null
          : 'POINT(${rallyPoint!.lon} ${rallyPoint!.lat})',
      'link': link?.toString(),
      'notes': notes,
      'banner_photo': bannerPhoto?.toString(),
    };
  }
}

/// Represents a persisted instance with all required fields
class PersistedInstance extends Instance {
  PersistedInstance({
    required this.id,
    required this.createdAt,
    required this.createdBy,
    this.createdById,
    this.updatedAt,
    required this.status,
    required super.startTimeMin,
    required super.startTimeMax,
    super.endTime,
    super.topic,
    super.topicId,
    required super.title,
    required super.visibility,
    required super.locationDescription,
    super.rallyPoint,
    super.link,
    super.notes,
    super.bannerPhoto,
  }) : assert(
            createdById == null ||
                createdBy == null ||
                createdBy.id == createdById,
            'createdBy.id and createdById must match if both are set');

  final InstanceID id;
  final DateTime createdAt;
  final UserProfile createdBy;
  final UserID? createdById;
  final DateTime? updatedAt;
  final InstanceStatus status;

  static PersistedInstance fromMap(Map<String, dynamic> map) {
    // Validate required fields for persisted instances
    if (!map.containsKey('id')) {
      throw FormatException('Missing required field: id');
    }
    if (!map.containsKey('created_at')) {
      throw FormatException('Missing required field: created_at');
    }
    if (!map.containsKey('created_by')) {
      throw FormatException('Missing required field: created_by');
    }
    if (!map.containsKey('title')) {
      throw FormatException('Missing required field: title');
    }
    if (!map.containsKey('location_description')) {
      throw FormatException('Missing required field: location_description');
    }
    if (!map.containsKey('start_time_min')) {
      throw FormatException('Missing required field: start_time_min');
    }
    if (!map.containsKey('start_time_max')) {
      throw FormatException('Missing required field: start_time_max');
    }

    final createdByModel = map['created_by'] is UserProfile
        ? map['created_by']
        : map['created_by'] is Map
            ? UserProfile.fromMap(map['created_by'])
            : null;

    if (createdByModel == null) {
      throw FormatException('Invalid created_by data');
    }

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

    return PersistedInstance(
      id: map['id'] as InstanceID,
      createdAt: DateTime.parse(map['created_at']).toLocal(),
      createdBy: createdByModel,
      createdById: createdByModel.id,
      updatedAt: map['updated_at'] == null
          ? null
          : DateTime.parse(map['updated_at']).toLocal(),
      status: map['status'] == null
          ? InstanceStatus.live
          : InstanceStatus.values.firstWhere(
              (e) => e.name == map['status'],
              orElse: () => InstanceStatus.live,
            ),
      startTimeMin: DateTime.parse(map['start_time_min']).toLocal(),
      startTimeMax: DateTime.parse(map['start_time_max']).toLocal(),
      endTime: map['end_time'] == null
          ? null
          : DateTime.parse(map['end_time']).toLocal(),
      topic: topicModel,
      topicId: topicModel == null ? map['topic'] as TopicID? : topicModel.id,
      title: map['title'] as String,
      visibility: map['visibility'] == null
          ? InstanceVisibility.friends
          : InstanceVisibility.values.firstWhere(
              (e) => e.name == map['visibility'],
              orElse: () => InstanceVisibility.friends,
            ),
      locationDescription: map['location_description'] as String,
      rallyPoint: map['rally_point_text'] == null
          ? null
          : Geographic(
              lon: double.parse(longitude), lat: double.parse(latitude)),
      link: map['link'] == null ? null : Uri.parse(map['link']),
      notes: map['notes'],
      bannerPhoto:
          map['banner_photo'] == null ? null : Uri.parse(map['banner_photo']),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final data = {
      'id': id,
      'created_at': createdAt.toUtc().toIso8601String(),
      'created_by': createdBy.id,
      'status': status.name,
      'start_time_min': startTimeMin.toUtc().toIso8601String(),
      'start_time_max': startTimeMax.toUtc().toIso8601String(),
      'end_time': endTime?.toUtc().toIso8601String(),
      'topic': topic?.id ?? topicId,
      'title': title,
      'visibility': visibility.name,
      'location_description': locationDescription,
      'rally_point': rallyPoint == null
          ? null
          : 'POINT(${rallyPoint!.lon} ${rallyPoint!.lat})',
      'link': link?.toString(),
      'notes': notes,
      'banner_photo': bannerPhoto?.toString(),
    };

    if (updatedAt != null) {
      data['updated_at'] = updatedAt!.toUtc().toIso8601String();
    }

    return data;
  }

  @override
  String toString() {
    return 'PersistedInstance{id: $id, title: $title}';
  }
}

class InstanceMember implements Hydratable {
  InstanceMember({
    required this.id,
    required this.createdAt,
    required this.createdBy,
    this.createdById,
    this.instance,
    this.instanceId,
    this.member,
    this.memberId,
    required this.status,
  })  : assert(
            createdById == null ||
                createdBy == null ||
                createdBy.id == createdById,
            'createdBy.id and createdById must match if both are set'),
        assert(
            instance == null || instanceId == null || instance.id == instanceId,
            'instance.id and instanceId must match if both are set'),
        assert(member == null || memberId == null || member.id == memberId,
            'member.id and memberId must match if both are set');

  final InstanceID id;
  final DateTime createdAt;
  final UserProfile createdBy;
  final UserID? createdById;
  final PersistedInstance? instance;
  final InstanceID? instanceId;
  final UserProfile? member;
  final UserID? memberId;
  final InstanceMemberStatus status;

  static InstanceMember fromMap(Map<String, dynamic> map) {
    if (!map.containsKey('id')) {
      throw FormatException('Missing required field: id');
    }
    if (!map.containsKey('created_at')) {
      throw FormatException('Missing required field: created_at');
    }
    if (!map.containsKey('created_by')) {
      throw FormatException('Missing required field: created_by');
    }
    if (!map.containsKey('status')) {
      throw FormatException('Missing required field: status');
    }

    final createdByModel = map['created_by'] is UserProfile
        ? map['created_by']
        : map['created_by'] is Map
            ? UserProfile.fromMap(map['created_by'])
            : null;

    if (createdByModel == null) {
      throw FormatException('Invalid created_by data');
    }

    final instanceModel = map['instance'] is PersistedInstance
        ? map['instance']
        : map['instance'] is Map
            ? PersistedInstance.fromMap(map['instance'])
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
      createdById: createdByModel.id,
      instance: instanceModel,
      instanceId: instanceModel == null
          ? map['instance'] as InstanceID?
          : instanceModel.id,
      member: memberModel,
      memberId: memberModel == null ? map['member'] as UserID? : memberModel.id,
      status: InstanceMemberStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => InstanceMemberStatus.invited,
      ),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'created_at': createdAt.toUtc().toIso8601String(),
      'created_by': createdBy.id,
      'instance': instance?.id ?? instanceId,
      'member': member?.id ?? memberId,
      'status': status.name,
    };
  }

  @override
  String toString() {
    return 'InstanceMember{instance: $instanceId, member: $memberId, status: $status}';
  }
}
