import 'package:flutter/material.dart';
import 'package:squadquest/models/user.dart';

typedef FriendID = String;

enum FriendStatus { requested, declined, accepted }

Map<FriendStatus, Icon> friendStatusIcons = {
  FriendStatus.requested: const Icon(Icons.pending),
  FriendStatus.declined: const Icon(Icons.cancel),
  FriendStatus.accepted: const Icon(Icons.approval),
};

class Friend {
  Friend({
    this.id,
    this.createdAt,
    this.actionedAt,
    this.requester,
    this.requesterId,
    this.requestee,
    this.requesteeId,
    this.mutualFriendCount = 0,
    required this.status,
  });

  final FriendID? id;
  final DateTime? createdAt;
  final DateTime? actionedAt;
  final UserProfile? requester;
  final UserID? requesterId;
  final UserProfile? requestee;
  final UserID? requesteeId;
  final int mutualFriendCount;
  final FriendStatus status;

  UserProfile? getOtherProfile(UserID userId) {
    if (requesterId == userId) {
      return requestee;
    } else if (requesteeId == userId) {
      return requester;
    }

    return null;
  }

  factory Friend.fromMap(Map<String, dynamic> map) {
    final requesterModel = map['requester'] is UserProfile
        ? map['requester']
        : map['requester'] is Map
            ? UserProfile.fromMap(map['requester'])
            : null;

    final requesteeModel = map['requestee'] is UserProfile
        ? map['requestee']
        : map['requestee'] is Map
            ? UserProfile.fromMap(map['requestee'])
            : null;

    return Friend(
      id: map['id'] as FriendID,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at']).toLocal()
          : null,
      actionedAt: map['actioned_at'] != null
          ? DateTime.parse(map['actioned_at']).toLocal()
          : null,
      requester: requesterModel,
      requesterId: requesterModel == null
          ? map['requester'] as UserID
          : requesterModel.id,
      requestee: requesteeModel,
      requesteeId: requesteeModel == null
          ? map['requestee'] as UserID
          : requesteeModel.id,
      mutualFriendCount: map['mutual_friend_count'] as int? ?? 0,
      status: FriendStatus.values.firstWhere(
        (e) => e.name == map['status'],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    final data = {
      'requester': requester?.id ?? requesterId,
      'requestee': requestee?.id ?? requesteeId,
      'status': status.name,
      'mutual_friend_count': mutualFriendCount,
    };

    if (id != null) {
      data['id'] = id!;
    }

    if (actionedAt != null) {
      data['actioned_at'] = actionedAt!.toUtc().toIso8601String();
    }

    return data;
  }

  @override
  String toString() {
    return 'Friend{id: $id, requester: $requester, requestee: $requestee, status: $status}';
  }
}
