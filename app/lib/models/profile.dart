/// A user profile (specs/api/auth.md). Tolerant reader: unknown fields ignored
/// so additive backend changes don't break the client. Read-only DTO — no
/// toJson/copyWith needed yet (added if/when we edit profiles client-side).
class Profile {
  const Profile({
    required this.id,
    this.firstName,
    this.lastName,
    this.photo,
    this.phone,
    this.claimedAt,
  });

  final String id;
  final String? firstName;
  final String? lastName;
  final String? photo;
  final String? phone;
  final DateTime? claimedAt;

  String get displayName =>
      [firstName, lastName].whereType<String>().join(' ').trim();

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    firstName: json['first_name'] as String?,
    lastName: json['last_name'] as String?,
    photo: json['photo'] as String?,
    phone: json['phone'] as String?,
    claimedAt: json['claimed_at'] == null
        ? null
        : DateTime.tryParse(json['claimed_at'] as String),
  );
}
