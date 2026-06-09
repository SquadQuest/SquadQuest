/// An idea or confirmed activity on a timeline (specs/api/ideas-activities.md).
/// Tolerant reader — only the fields this stage's UI needs are modeled in depth;
/// unknown fields are ignored.
class Activity {
  const Activity({
    required this.id,
    required this.state,
    this.captainName,
    this.activityTypeLabel,
    this.audienceSummary,
    this.allowSuggestions = false,
    this.confirmedTime,
    this.confirmedLocation,
    this.yourResponse,
    this.inCount = 0,
    this.interestedCount = 0,
    this.timeOptions = const [],
    this.locationOptions = const [],
  });

  final String id;
  final String state; // 'idea' | 'confirmed'
  final String? captainName;
  final String? activityTypeLabel;
  final String? audienceSummary;
  final bool allowSuggestions;
  final String? confirmedTime;
  final String? confirmedLocation;
  final String? yourResponse; // 'in' | 'interested' | 'next_time' | null
  final int inCount;
  final int interestedCount;
  final List<ActivityOption> timeOptions;
  final List<ActivityOption> locationOptions;

  bool get isConfirmed => state == 'confirmed';

  factory Activity.fromJson(Map<String, dynamic> json) {
    final captain = json['captain'] as Map<String, dynamic>?;
    final type = json['activity_type'] as Map<String, dynamic>?;
    final audience = json['audience'] as Map<String, dynamic>?;
    final counts = json['counts'] as Map<String, dynamic>? ?? const {};
    List<ActivityOption> opts(String key) =>
        ((json[key] as List<dynamic>?) ?? const [])
            .map((e) => ActivityOption.fromJson(e as Map<String, dynamic>))
            .toList();

    return Activity(
      id: json['id'] as String,
      state: json['state'] as String? ?? 'idea',
      captainName: captain?['first_name'] as String?,
      activityTypeLabel: type?['label'] as String?,
      audienceSummary: audience?['summary'] as String?,
      allowSuggestions: json['allow_suggestions'] as bool? ?? false,
      confirmedTime: json['confirmed_time'] as String?,
      confirmedLocation: json['confirmed_location'] as String?,
      yourResponse: json['your_response'] as String?,
      inCount: (counts['in'] as num?)?.toInt() ?? 0,
      interestedCount: (counts['interested'] as num?)?.toInt() ?? 0,
      timeOptions: opts('time_options'),
      locationOptions: opts('location_options'),
    );
  }
}

class ActivityOption {
  const ActivityOption({
    required this.id,
    required this.label,
    this.votes = 0,
    this.youVoted = false,
  });

  final String id;
  final String label;
  final int votes;
  final bool youVoted;

  factory ActivityOption.fromJson(Map<String, dynamic> json) => ActivityOption(
    id: json['id'] as String,
    label: json['label'] as String? ?? '',
    votes: (json['votes'] as num?)?.toInt() ?? 0,
    youVoted: json['you_voted'] as bool? ?? false,
  );
}
