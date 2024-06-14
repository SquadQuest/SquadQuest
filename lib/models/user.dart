import 'package:squadquest/common.dart';

typedef UserID = String;

class UserProfile {
  UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
  });

  final UserID id;
  final String firstName;
  final String lastName;
  final String phone;

  String get fullName => '$firstName $lastName';
  String get phoneFormatted => formatPhone(phone);

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as UserID,
      firstName: map['first_name'] as String,
      lastName: map['last_name'] as String,
      phone: map['phone'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone
    };
  }

  @override
  String toString() {
    return 'UserProfile{id: $id, firstName: $firstName, lastName: $lastName}';
  }
}
