/// A friend in the accepted graph (specs/api/timeline.md / v1-migration). `onV2`
/// false = a carried friendship whose other party hasn't claimed v2 yet.
class Friend {
  const Friend({
    required this.id,
    this.firstName,
    this.lastName,
    this.photo,
    this.onV2 = false,
  });

  final String id;
  final String? firstName;
  final String? lastName;
  final String? photo;
  final bool onV2;

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
    id: json['id'] as String,
    firstName: json['first_name'] as String?,
    lastName: json['last_name'] as String?,
    photo: json['photo'] as String?,
    onV2: json['on_v2'] as bool? ?? false,
  );
}
