/// An open, followable community (specs/api/communities.md).
class Community {
  const Community({
    required this.id,
    required this.name,
    this.tagline,
    this.icon,
    this.color,
    this.photo,
    this.followerCount = 0,
    this.youFollow = false,
    this.yourRole,
  });

  final String id;
  final String name;
  final String? tagline;
  final String? icon;
  final String? color;
  final String? photo;
  final int followerCount;
  final bool youFollow;

  /// `'leader'` when the caller may post/edit this community's events, else null.
  final String? yourRole;

  bool get isLeader => yourRole == 'leader';

  factory Community.fromJson(Map<String, dynamic> json) => Community(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    tagline: json['tagline'] as String?,
    icon: json['icon'] as String?,
    color: json['color'] as String?,
    photo: json['photo'] as String?,
    followerCount: (json['follower_count'] as num?)?.toInt() ?? 0,
    youFollow: json['you_follow'] as bool? ?? false,
    yourRole: json['your_role'] as String?,
  );
}

/// A leader-broadcast, born-confirmed recurring event + the viewer's RSVP.
class CommunityEvent {
  const CommunityEvent({
    required this.id,
    required this.title,
    this.communityName,
    this.communityIcon,
    this.activityTypeLabel,
    this.time,
    this.recurrence,
    this.location,
    this.goingCount = 0,
    this.publicGoing = const [],
    this.youGoing = false,
    this.youPublic = false,
    this.threadCount = 0,
  });

  final String id;
  final String title;
  final String? communityName;
  final String? communityIcon;
  final String? activityTypeLabel;
  final String? time;
  final String? recurrence;
  final String? location;
  final int goingCount;
  final List<String> publicGoing; // first names for the face-pile
  final bool youGoing;
  final bool youPublic;
  final int threadCount;

  factory CommunityEvent.fromJson(Map<String, dynamic> json) {
    final community = json['community'] as Map<String, dynamic>?;
    final type = json['activity_type'] as Map<String, dynamic>?;
    final rsvp = json['your_rsvp'] as Map<String, dynamic>? ?? const {};
    return CommunityEvent(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      communityName: community?['name'] as String?,
      communityIcon: community?['icon'] as String?,
      activityTypeLabel: type?['label'] as String?,
      time: json['time'] as String?,
      recurrence: json['recurrence'] as String?,
      location: json['location'] as String?,
      goingCount: (json['going_count'] as num?)?.toInt() ?? 0,
      publicGoing: ((json['public_going'] as List<dynamic>?) ?? const [])
          .map(
            (e) => (e as Map<String, dynamic>)['first_name'] as String? ?? '',
          )
          .where((s) => s.isNotEmpty)
          .toList(),
      youGoing: rsvp['going'] as bool? ?? false,
      youPublic: rsvp['public'] as bool? ?? false,
      threadCount: (json['thread_count'] as num?)?.toInt() ?? 0,
    );
  }
}
