import 'package:squadquest/common.dart';

typedef UserID = String;

class UserProfile {
  UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.fcmToken,
    required this.photo,
  });

  final UserID id;
  final String firstName;
  final String? lastName;
  final String? phone;
  final String? fcmToken;
  final Uri? photo;

  String get fullName => '$firstName $lastName';
  String get displayName => lastName == null ? firstName : fullName;
  String? get phoneFormatted => phone == null ? null : formatPhone(phone!);
  Uri? get phoneUri =>
      phone == null ? null : Uri(scheme: 'tel', path: phoneFormatted);

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as UserID,
      firstName: map['first_name'] as String,
      lastName: map['last_name'] == null ? null : map['last_name'] as String,
      phone: map['phone'],
      fcmToken: map['fcm_token'],
      photo: map['photo'] == null ? null : Uri.parse(map['photo']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'fcm_token': fcmToken,
      'photo': photo?.toString(),
    };
  }

  @override
  String toString() {
    return 'UserProfile{id: $id, firstName: $firstName, lastName: $lastName}';
  }
}
