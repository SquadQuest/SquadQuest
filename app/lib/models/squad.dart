/// A squad — a closed, persistent named group (specs/screens/squads.md).
class Squad {
  const Squad({
    required this.id,
    required this.name,
    this.role,
    this.memberCount = 0,
  });

  final String id;
  final String name;
  final String? role; // 'captain' | 'member'
  final int memberCount;

  factory Squad.fromJson(Map<String, dynamic> json) => Squad(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    role: json['role'] as String?,
    memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
  );
}

class SquadMember {
  const SquadMember({required this.id, this.firstName, this.photo, this.role});
  final String id;
  final String? firstName;
  final String? photo;
  final String? role;

  factory SquadMember.fromJson(Map<String, dynamic> json) => SquadMember(
    id: json['id'] as String,
    firstName: json['first_name'] as String?,
    photo: json['photo'] as String?,
    role: json['role'] as String?,
  );
}

class SquadDetail {
  const SquadDetail({
    required this.id,
    required this.name,
    this.members = const [],
  });
  final String id;
  final String name;
  final List<SquadMember> members;

  factory SquadDetail.fromJson(Map<String, dynamic> json) => SquadDetail(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    members: ((json['members'] as List<dynamic>?) ?? const [])
        .map((e) => SquadMember.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
