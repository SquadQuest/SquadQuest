part of '../community_timeline.dart';

// ============================================================================
// Data Classes
// ============================================================================

class _MockPerson {
  final String name;
  final String initial;
  final Color color;

  _MockPerson({
    required this.name,
    required this.initial,
    required this.color,
  });
}

class _MockSquad {
  final String name;
  final int memberCount;

  _MockSquad({required this.name, required this.memberCount});
}

// Base sealed class for timeline items
sealed class _TimelineItem {
  final String id;
  final DateTime timestamp;

  _TimelineItem({required this.id, required this.timestamp});
}

class _IdeaItem extends _TimelineItem {
  final String activityType;
  final _MockPerson captain;
  final String audienceLabel;
  final List<String> proposedTimes;
  final List<String> proposedLocations;
  final bool allowSuggestions;
  final int interestedCount;
  final int threadMessageCount;

  _IdeaItem({
    required super.id,
    required super.timestamp,
    required this.activityType,
    required this.captain,
    required this.audienceLabel,
    required this.proposedTimes,
    required this.proposedLocations,
    required this.allowSuggestions,
    required this.interestedCount,
    required this.threadMessageCount,
  });
}

class _ActivityItem extends _TimelineItem {
  final String activityType;
  final _MockPerson captain;
  final String audienceLabel;
  final String confirmedTime;
  final String confirmedLocation;
  final int goingCount;
  final int threadMessageCount;

  _ActivityItem({
    required super.id,
    required super.timestamp,
    required this.activityType,
    required this.captain,
    required this.audienceLabel,
    required this.confirmedTime,
    required this.confirmedLocation,
    required this.goingCount,
    required this.threadMessageCount,
  });
}

class _SquadTextMessage extends _TimelineItem {
  final _MockPerson sender;
  final String? content;
  final List<String>? photos;
  final int threadMessageCount;

  _SquadTextMessage({
    required super.id,
    required super.timestamp,
    required this.sender,
    this.content,
    this.photos,
    required this.threadMessageCount,
  });
}

class _ThreadMessage {
  final _MockPerson? sender;
  final String? content;
  final List<String>? photos;
  final DateTime timestamp;
  final bool isSystem;

  _ThreadMessage({
    this.sender,
    this.content,
    this.photos,
    required this.timestamp,
    this.isSystem = false,
  });
}

class _VoteOption {
  final String id;
  final String label;
  final List<_MockPerson> voters;

  _VoteOption({
    required this.id,
    required this.label,
    required this.voters,
  });
}
