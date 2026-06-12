/// A loose, shared pre-activity (specs/api/wants.md, screens/wants.md): an intent
/// (topic + optional title/location/notes) plus the friends you'd do it with.
/// Tolerant reader — unknown fields ignored.
class Want {
  const Want({
    required this.id,
    this.ownerId,
    this.ownerName,
    this.activityTypeId,
    this.activityTypeLabel,
    this.title,
    this.location,
    this.notes,
    this.kind = 'one_shot',
    this.invitees = const [],
    this.yourResponse,
    this.archivedAt,
  });

  final String id;
  final String? ownerId;
  final String? ownerName;
  final String? activityTypeId;
  final String? activityTypeLabel;
  final String? title;
  final String? location;
  final String? notes;
  final String kind; // 'one_shot' | 'ongoing'
  final List<WantInvitee> invitees;
  final String?
  yourResponse; // set when you're an invitee: in|interested|next_time|null
  final DateTime? archivedAt;

  bool get isOngoing => kind == 'ongoing';
  bool get isArchived => archivedAt != null;

  factory Want.fromJson(Map<String, dynamic> json) {
    final owner = json['owner'] as Map<String, dynamic>?;
    final type = json['activity_type'] as Map<String, dynamic>?;
    return Want(
      id: json['id'] as String,
      ownerId: owner?['id'] as String?,
      ownerName: owner?['first_name'] as String?,
      activityTypeId: type?['id'] as String?,
      activityTypeLabel: type?['label'] as String?,
      title: json['title'] as String?,
      location: json['location'] as String?,
      notes: json['notes'] as String?,
      kind: json['kind'] as String? ?? 'one_shot',
      invitees: ((json['invitees'] as List<dynamic>?) ?? const [])
          .map((e) => WantInvitee.fromJson(e as Map<String, dynamic>))
          .toList(),
      yourResponse: json['your_response'] as String?,
      archivedAt: json['archived_at'] == null
          ? null
          : DateTime.tryParse(json['archived_at'] as String),
    );
  }
}

/// A friend invited to a want, with their soft response (null = not yet responded).
class WantInvitee {
  const WantInvitee({
    required this.profileId,
    this.name,
    this.photo,
    this.response,
  });

  final String profileId;
  final String? name;
  final String? photo;
  final String? response; // 'in' | 'interested' | 'next_time' | null

  factory WantInvitee.fromJson(Map<String, dynamic> json) {
    final p = json['profile'] as Map<String, dynamic>?;
    return WantInvitee(
      profileId: p?['id'] as String? ?? '',
      name: p?['first_name'] as String?,
      photo: p?['photo'] as String?,
      response: json['response'] as String?,
    );
  }
}
