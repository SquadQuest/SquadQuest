typedef UserID = String;

class UserProfile {
  UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
  });

  final UserID id;
  final String firstName;
  final String lastName;

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as UserID,
      firstName: map['first_name'] as String,
      lastName: map['last_name'] as String,
    );
  }

  // Map<String, dynamic> toMap() {
  //   ...
  // }
}
