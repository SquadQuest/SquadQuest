typedef TopicID = String;

class Topic {
  Topic({
    required this.id,
    required this.name,
  });

  final TopicID? id;
  final String name;

  factory Topic.fromMap(Map<String, dynamic> map) {
    return Topic(
      id: map['id'] as TopicID,
      name: map['name'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    final data = {
      'name': name,
    };

    if (id != null) {
      data['id'] = id!;
    }

    return data;
  }

  @override
  String toString() {
    return 'Topic{id: $id, name: $name}';
  }
}
