typedef TopicID = String;

final defaultPrivateTopic = Topic(
  id: '12df1321-1c0a-4f9d-85aa-4a235a36d3a8',
  name: 'misc.hangout',
);

class Topic {
  Topic({
    required this.id,
    required this.name,
  });

  final TopicID? id;
  final String name;

  bool get isNull => id == null && name.isEmpty;
  bool get isNotNull => !isNull;

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
