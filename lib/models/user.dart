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
      this.trailColor,
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
  final String? trailColor;
  final Set<NotificationType> enabledNotifications;
  final List<UserID>? mutuals;
  final Set<String> unparsedNotifications;

  String get fullName => '$firstName $lastName';
  String get displayName => lastName == null ? firstName : fullName;
  String? get phoneFormatted => phone == null ? null : formatPhone(phone!);
  Uri? get phoneUri =>
      phone == null ? null : Uri(scheme: 'tel', path: phoneFormatted);

  // Get effective trail color (custom or generated)
  String get effectiveTrailColor => trailColor ?? generateTrailColor(id);

  // Generate a trail color for a user ID
  static String generateTrailColor(String userId) {
    // Remove dashes and get first 8 chars for more entropy
    final cleanUuid = userId.replaceAll('-', '').substring(0, 8);

    // Convert to integer for calculations
    final value = int.parse(cleanUuid, radix: 16);

    // Generate HSL values:
    // Hue: Use full range (0-360) for color variety
    // Saturation: Keep high (70-100%) for vibrant colors
    // Lightness: Keep high (60-80%) for visibility on dark backgrounds
    final hue = value % 360;
    final saturation = 70 + (value % 30); // 70-100%
    final lightness = 60 + (value % 20); // 60-80%

    // Convert HSL to RGB
    final rgb = _hslToRgb(hue / 360, saturation / 100, lightness / 100);

    // Convert RGB to hex
    return '#${rgb.map((c) => c.toRadixString(16).padLeft(2, '0')).join('')}';
  }

  // Helper function to convert HSL to RGB
  static List<int> _hslToRgb(double h, double s, double l) {
    double r, g, b;

    if (s == 0) {
      r = g = b = l;
    } else {
      double hue2rgb(double p, double q, double t) {
        if (t < 0) t += 1;
        if (t > 1) t -= 1;
        if (t < 1 / 6) return p + (q - p) * 6 * t;
        if (t < 1 / 2) return q;
        if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
        return p;
      }

      final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
      final p = 2 * l - q;
      r = hue2rgb(p, q, h + 1 / 3);
      g = hue2rgb(p, q, h);
      b = hue2rgb(p, q, h - 1 / 3);
    }

    return [(r * 255).round(), (g * 255).round(), (b * 255).round()];
  }

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
      trailColor: map['trail_color'],
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
      'trail_color': trailColor,
    };
  }

  @override
  String toString() {
    return 'UserProfile{id: $id, firstName: $firstName, lastName: $lastName}';
  }
}
