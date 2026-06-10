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

  String get displayName =>
      [firstName, lastName].whereType<String>().join(' ').trim();
}

/// A pending connection request (specs/api/friends.md). `profile` is the *other*
/// party — the sender for an incoming request, the target for an outgoing one.
class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.profile,
    this.createdAt,
  });

  final String id;
  final Friend profile;
  final DateTime? createdAt;

  factory FriendRequest.fromJson(Map<String, dynamic> json) => FriendRequest(
    id: json['id'] as String,
    profile: Friend.fromJson(json['profile'] as Map<String, dynamic>),
    createdAt: json['created_at'] == null
        ? null
        : DateTime.tryParse(json['created_at'] as String),
  );
}

/// The caller's pending requests, split by direction.
class FriendRequests {
  const FriendRequests({this.incoming = const [], this.outgoing = const []});

  final List<FriendRequest> incoming;
  final List<FriendRequest> outgoing;

  factory FriendRequests.fromJson(Map<String, dynamic> json) => FriendRequests(
    incoming: ((json['incoming'] as List<dynamic>?) ?? const [])
        .map((e) => FriendRequest.fromJson(e as Map<String, dynamic>))
        .toList(),
    outgoing: ((json['outgoing'] as List<dynamic>?) ?? const [])
        .map((e) => FriendRequest.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
