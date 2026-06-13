/// An activity type (specs/api/topics.md): a noun/verb pair with a display label,
/// chosen when composing an idea. `kind` official|community; official lists first.
class Topic {
  const Topic({
    required this.id,
    required this.label,
    this.noun,
    this.verb,
    this.kind = 'official',
    this.category,
  });

  final String id;
  final String label;
  final String? noun;
  final String? verb;
  final String kind; // 'official' | 'community'
  final String? category;

  bool get isOfficial => kind == 'official';

  factory Topic.fromJson(Map<String, dynamic> json) => Topic(
    id: json['id'] as String,
    label: json['label'] as String? ?? '',
    noun: json['noun'] as String?,
    verb: json['verb'] as String?,
    kind: json['kind'] as String? ?? 'official',
    category: json['category'] as String?,
  );
}
