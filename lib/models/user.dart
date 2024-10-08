import 'package:squadquest/common.dart';

typedef UserID = String;

enum NotificationType {
  friendRequest,
  eventInvitation,
  eventChange,
  friendsEventPosted,
  publicEventPosted,
  guestRsvp,
  friendOnTheWay,
  eventMessage
}

class UserProfile {
  UserProfile(
      {required this.id,
      required this.firstName,
      required this.lastName,
      required this.phone,
      required this.fcmToken,
      required this.fcmTokenUpdatedAt,
      required this.fcmTokenAppBuild,
      required this.photo,
      required this.enabledNotifications,
      this.mutuals,
      this.unparsedNotifications = const {}});

  final UserID id;
  final String firstName;
  final String? lastName;
  final String? phone;
  final String? fcmToken;
  final DateTime? fcmTokenUpdatedAt;
  final int? fcmTokenAppBuild;
  final Uri? photo;
  final Set<NotificationType> enabledNotifications;
  final List<UserID>? mutuals;
  final Set<String> unparsedNotifications;

  String get fullName => '$firstName $lastName';
  String get displayName => lastName == null ? firstName : fullName;
  String? get phoneFormatted => phone == null ? null : formatPhone(phone!);
  Uri? get phoneUri =>
      phone == null ? null : Uri(scheme: 'tel', path: phoneFormatted);

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final Set<NotificationType> parsedNotifications = {};
    final Set<String> unparsedNotifications = {};

    if (map['enabled_notifications_v2'] != null) {
      for (final type in map['enabled_notifications_v2']) {
        try {
          parsedNotifications.add(NotificationType.values.firstWhere(
            (e) => e.name == type,
          ));
        } catch (e) {
          unparsedNotifications.add(type);
        }
      }
    }

    return UserProfile(
      id: map['id'] as UserID,
      firstName: map['first_name'] as String,
      lastName: map['last_name'] == null ? null : map['last_name'] as String,
      phone: map['phone'],
      fcmToken: map['fcm_token'],
      fcmTokenUpdatedAt: map['fcm_token_updated_at'] == null
          ? null
          : DateTime.parse(map['fcm_token_updated_at']).toLocal(),
      fcmTokenAppBuild: map['fcm_token_app_build'],
      photo: map['photo'] == null ? null : Uri.parse(map['photo']),
      enabledNotifications: parsedNotifications,
      unparsedNotifications: unparsedNotifications,
      mutuals:
          map['mutuals'] == null ? null : List<UserID>.from(map['mutuals']),
    );
  }

  Map<String, dynamic> toMap() {
    final enabledNotificationsFull =
        enabledNotifications.map((type) => type.name).toList().cast<String>();

    enabledNotificationsFull.addAll(unparsedNotifications);

    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'fcm_token': fcmToken,
      'fcm_token_updated_at': fcmTokenUpdatedAt?.toUtc().toIso8601String(),
      'fcm_token_app_build': fcmTokenAppBuild,
      'enabled_notifications_v2': enabledNotificationsFull,
      'photo': photo?.toString(),
    };
  }

  @override
  String toString() {
    return 'UserProfile{id: $id, firstName: $firstName, lastName: $lastName}';
  }
}
