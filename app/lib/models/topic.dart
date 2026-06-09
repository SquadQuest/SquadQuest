/// An activity type (specs/api/ideas-activities.md): a noun/verb pair with a
/// display label, chosen when composing an idea.
class Topic {
  const Topic({required this.id, required this.label, this.noun, this.verb});

  final String id;
  final String label;
  final String? noun;
  final String? verb;

  factory Topic.fromJson(Map<String, dynamic> json) => Topic(
    id: json['id'] as String,
    label: json['label'] as String? ?? '',
    noun: json['noun'] as String?,
    verb: json['verb'] as String?,
  );
}
