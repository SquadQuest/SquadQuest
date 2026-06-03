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

/// An open, followable group that broadcasts events to its followers.
/// Unlike squads (closed, everyone posts), only community leaders post events.
class _MockCommunity {
  final String name;
  final int followerCount;
  final Color color;
  final IconData icon;
  final String tagline;

  _MockCommunity({
    required this.name,
    required this.followerCount,
    required this.color,
    required this.icon,
    required this.tagline,
  });
}

/// A lightweight reference embedded in a friend-scoped idea/activity that points
/// at a community event the captain is bringing friends to. The public event
/// stays owned by the community; this is just the read-only anchor shown inside
/// the private friend plan.
class _EventRef {
  final String communityName;
  final String eventTitle;
  final IconData communityIcon;
  final Color communityColor;

  /// The event's fixed time/place — the idea→activity transition for a
  /// brought-along plan locks these in (they came from the event, not a vote).
  final String eventTime;
  final String eventLocation;

  _EventRef({
    required this.communityName,
    required this.eventTitle,
    required this.communityIcon,
    required this.communityColor,
    required this.eventTime,
    required this.eventLocation,
  });
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

  /// Set when this idea is a friend brought along to a community event.
  /// The event's time/place are already locked, so this idea only gathers
  /// who's coming — the time/location axis is pre-resolved by [eventRef].
  final _EventRef? eventRef;

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
    this.eventRef,
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

  /// Set when this confirmed plan is a friend group going to a community event.
  final _EventRef? eventRef;

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
    this.eventRef,
  });
}

/// An event broadcast by a community leader. Born confirmed (no idea/voting
/// stage) and recurring. Audience is the community's followers, surfaced as a
/// dual count: [goingCount] is the total distinct attendees (anonymous), while
/// [publicGoing] is the subset who chose to make their attendance visible.
class _CommunityEventItem extends _TimelineItem {
  final _MockCommunity community;
  final String title;
  final String activityType;
  final String time;
  final String recurrence;
  final String location;
  final int goingCount;
  final List<_MockPerson> publicGoing;
  final int threadMessageCount;

  _CommunityEventItem({
    required super.id,
    required super.timestamp,
    required this.community,
    required this.title,
    required this.activityType,
    required this.time,
    required this.recurrence,
    required this.location,
    required this.goingCount,
    required this.publicGoing,
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
