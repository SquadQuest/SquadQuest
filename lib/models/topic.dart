typedef TopicID = String;

final defaultPrivateTopic = Topic(
  id: '12df1321-1c0a-4f9d-85aa-4a235a36d3a8',
  name: 'misc.hangout',
);

class Topic {
  Topic({
    required this.id,
    required this.name,
    this.displayName,
    this.embedding,
  });

  final TopicID? id;
  final String name;
  final String? displayName;
  final List<double>? embedding;

  String get label => displayName ?? name;

  bool get isNull => id == null && name.isEmpty;
  bool get isNotNull => !isNull;

  factory Topic.fromMap(Map<String, dynamic> map) {
    return Topic(
      id: map['id'] as TopicID,
      name: map['name'] as String,
      displayName: map['display_name'] as String?,
      embedding: map['embedding'] != null
          ? (map['embedding'] as List)
              .map((e) => (e as num).toDouble())
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'name': name,
    };

    if (id != null) {
      data['id'] = id!;
    }

    if (displayName != null) {
      data['display_name'] = displayName;
    }

    if (embedding != null) {
      data['embedding'] = embedding;
    }

    return data;
  }

  @override
  String toString() {
    return 'Topic{id: $id, name: $name, displayName: $displayName}';
  }
}
