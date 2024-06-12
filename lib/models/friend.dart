import 'package:flutter/material.dart';
import 'package:squad_quest/models/user.dart';

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
    required this.status,
  });

  final FriendID? id;
  final DateTime? createdAt;
  final DateTime? actionedAt;
  final UserProfile? requester;
  final UserID? requesterId;
  final UserProfile? requestee;
  final UserID? requesteeId;
  final FriendStatus status;

  factory Friend.fromMap(Map<String, dynamic> map) {
    final requesterModel =
        map['requester'] is Map ? UserProfile.fromMap(map['requester']) : null;

    final requesteeModel =
        map['requestee'] is Map ? UserProfile.fromMap(map['requestee']) : null;

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
    };

    if (id != null) {
      data['id'] = id!;
    }

    if (actionedAt != null) {
      data['actioned_at'] = id!;
    }

    return data;
  }

  @override
  String toString() {
    return 'Friend{id: $id, requester: $requester, requestee: $requestee, status: $status}';
  }
}
