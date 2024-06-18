import 'package:squadquest/common.dart';

typedef UserID = String;

class UserProfile {
  UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.fcmToken,
  });

  final UserID id;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? fcmToken;

  String get fullName => '$firstName $lastName';
  String? get phoneFormatted => phone == null ? null : formatPhone(phone!);

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as UserID,
      firstName: map['first_name'] as String,
      lastName: map['last_name'] as String,
      phone: map['phone'],
      fcmToken: map['fcm_token'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'fcm_token': fcmToken,
    };
  }

  @override
  String toString() {
    return 'UserProfile{id: $id, firstName: $firstName, lastName: $lastName}';
  }
}
