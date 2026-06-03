import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadquest/app_scaffold.dart';

part 'community_timeline/models.dart';
part 'community_timeline/shared_widgets.dart';
part 'community_timeline/timeline_cards.dart';
part 'community_timeline/thread_drawer.dart';

// ============================================================================
// Mock People
// ============================================================================

final _you = _MockPerson(name: 'You', initial: 'Y', color: Colors.blueGrey);
final _katie = _MockPerson(name: 'Katie', initial: 'K', color: Colors.pink);
final _mike = _MockPerson(name: 'Mike', initial: 'M', color: Colors.blue);
final _sarah = _MockPerson(name: 'Sarah', initial: 'S', color: Colors.orange);
final _lisa = _MockPerson(name: 'Lisa', initial: 'L', color: Colors.purple);
final _john = _MockPerson(name: 'John', initial: 'J', color: Colors.green);
final _alex = _MockPerson(name: 'Alex', initial: 'A', color: Colors.teal);
final _rachel = _MockPerson(name: 'Rachel', initial: 'R', color: Colors.red);
final _dave = _MockPerson(name: 'Dave', initial: 'D', color: Colors.indigo);
final _maya = _MockPerson(name: 'Maya', initial: 'M', color: Colors.deepPurple);
final _jordan = _MockPerson(name: 'Jordan', initial: 'J', color: Colors.amber);

// ============================================================================
// Mock Squads
// ============================================================================

final _squads = [
  _MockSquad(name: 'Paddle Kru', memberCount: 8),
  _MockSquad(name: 'Weekend Hikers', memberCount: 12),
  _MockSquad(name: 'Game Night Crew', memberCount: 5),
];

// ============================================================================
// Mock Communities
//
// Open, followable groups whose leaders broadcast recurring events. Modeled on
// real Philly groups: a social bike ride, a music venue, and a donation yoga
// collective.
// ============================================================================

final _communities = [
  _MockCommunity(
    name: 'Wednesday Night Rides',
    followerCount: 342,
    color: Colors.teal,
    icon: Icons.directions_bike,
    tagline: 'Bi-weekly social bike rides',
  ),
  _MockCommunity(
    name: 'Black Squirrel Club',
    followerCount: 891,
    color: Colors.deepPurple,
    icon: Icons.music_note,
    tagline: 'Live music in a Fishtown steam plant',
  ),
  _MockCommunity(
    name: 'Philly River Flow',
    followerCount: 214,
    color: Colors.lightGreen,
    icon: Icons.self_improvement,
    tagline: 'Donation yoga on the Schuylkill banks',
  ),
];

// ============================================================================
// Community Timeline Screen
// ============================================================================

class CommunityTimelineScreen extends ConsumerStatefulWidget {
  const CommunityTimelineScreen({super.key});

  @override
  ConsumerState<CommunityTimelineScreen> createState() =>
      _CommunityTimelineScreenState();
}

class _CommunityTimelineScreenState
    extends ConsumerState<CommunityTimelineScreen> {
  final ScrollController _timelineScrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController threadMessageController = TextEditingController();
  final ScrollController threadScrollController = ScrollController();

  // Context selection. 'friends' is the default global view; otherwise holds a
  // squad name or a community name.
  String _selectedContext = 'friends';
  bool _showSquadDropdown = false;

  // Ideas the captain has confirmed (idea → activity). Keyed by idea id, value
  // is the locked-in time + location.
  final Map<String, ({String time, String location})> confirmedPlans = {};

  // Community-event RSVP state (the visibility gradient):
  //  - goingEvents: you're attending (counts toward the anonymous headcount)
  //  - publicEvents: you've also chosen to make your attendance visible
  final Set<String> goingEvents = {};
  final Set<String> publicEvents = {};

  // A community event staged for "bring friends" — pre-fills the idea composer.
  _EventRef? _pendingEventRef;

  // User responses to ideas/activities
  final Map<String, String?> userResponses = {
    'idea_rock_climbing': 'interested',
    'activity_picnic': 'in',
  };

  // Items where user tapped to re-expand response buttons
  final Set<String> expandedResponses = {};

  // Thread state
  String? activeThreadItemId;

  // Idea composer state
  bool _showIdeaComposer = false;
  String? _selectedActivityType;

  // Voting state
  final Set<String> userTimeVotes = {'time_paddle_sun'};
  final Set<String> userLocationVotes = {'loc_paddle_willamette'};
  bool showVotingExpanded = false;

  // Scroll state
  bool _showScrollToBottom = false;

  // ========================================================================
  // Mock Timeline Data
  // ========================================================================

  late final List<_TimelineItem> friendsItems = [
    _IdeaItem(
      id: 'idea_hiking',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      activityType: 'Hiking',
      captain: _john,
      audienceLabel: 'all friends',
      proposedTimes: ['Saturday 9am', 'Sunday 8am', 'Sunday 2pm'],
      proposedLocations: ['Forest Park', 'Eagle Creek'],
      allowSuggestions: true,
      interestedCount: 3,
      threadMessageCount: 2,
    ),
    // A friend brought along to a community event: the ride's time/place are
    // already locked by Wednesday Night Rides, so this idea just gathers who's
    // coming. It carries an embedded reference to the public event.
    _IdeaItem(
      id: 'idea_bring_ride',
      timestamp: DateTime.now().subtract(const Duration(minutes: 40)),
      activityType: 'Biking',
      captain: _you,
      audienceLabel: 'all friends',
      proposedTimes: [],
      proposedLocations: [],
      allowSuggestions: false,
      interestedCount: 2,
      threadMessageCount: 4,
      eventRef: _EventRef(
        communityName: 'Wednesday Night Rides',
        eventTitle: 'Cherry Blossoms Ride',
        communityIcon: Icons.directions_bike,
        communityColor: Colors.teal,
        eventTime: 'Wed Apr 1 · 6:30pm',
        eventLocation: 'Clark Park → Kelly Drive',
      ),
    ),
    _IdeaItem(
      id: 'idea_paddleboard',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      activityType: 'Paddleboarding',
      captain: _lisa,
      audienceLabel: 'you and 7 others',
      proposedTimes: ['Saturday 10am', 'Sunday 2pm'],
      proposedLocations: ['Willamette River'],
      allowSuggestions: true,
      interestedCount: 5,
      threadMessageCount: 6,
    ),
    _ActivityItem(
      id: 'activity_board_games',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      activityType: 'Board Games',
      captain: _sarah,
      audienceLabel: 'all friends',
      confirmedTime: 'Friday 7pm',
      confirmedLocation: 'Game Knight',
      goingCount: 4,
      threadMessageCount: 8,
    ),
    _IdeaItem(
      id: 'idea_rock_climbing',
      timestamp: DateTime.now().subtract(const Duration(hours: 26)),
      activityType: 'Rock Climbing',
      captain: _mike,
      audienceLabel: 'you and 4 others',
      proposedTimes: [],
      proposedLocations: [],
      allowSuggestions: true,
      interestedCount: 2,
      threadMessageCount: 3,
    ),
    _ActivityItem(
      id: 'activity_picnic',
      timestamp: DateTime.now().subtract(const Duration(hours: 50)),
      activityType: 'Picnic',
      captain: _katie,
      audienceLabel: 'all friends',
      confirmedTime: 'Saturday 2pm',
      confirmedLocation: 'Laurelhurst Park',
      goingCount: 6,
      threadMessageCount: 12,
    ),
  ];

  late final List<_TimelineItem> squadItems = [
    _SquadTextMessage(
      id: 'squad_msg_1',
      timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
      sender: _sarah,
      content: 'Great session today! Those new paddles are amazing',
      photos: ['paddle_photo_1.jpg'],
      threadMessageCount: 3,
    ),
    _IdeaItem(
      id: 'squad_idea_tournament',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      activityType: 'Pickleball',
      captain: _mike,
      audienceLabel: 'Paddle Kru',
      proposedTimes: ['Saturday 10am', 'Saturday 2pm'],
      proposedLocations: ['Montavilla Courts', 'Sellwood Park'],
      allowSuggestions: true,
      interestedCount: 4,
      threadMessageCount: 5,
    ),
    _SquadTextMessage(
      id: 'squad_msg_2',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      sender: _alex,
      content:
          'Has anyone tried the new courts at Sellwood? Heard they just resurfaced them.',
      threadMessageCount: 0,
    ),
    _SquadTextMessage(
      id: 'squad_msg_3',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      sender: _lisa,
      content: null,
      photos: ['courts_photo_1.jpg', 'courts_photo_2.jpg'],
      threadMessageCount: 1,
    ),
    _ActivityItem(
      id: 'squad_activity_practice',
      timestamp: DateTime.now().subtract(const Duration(hours: 20)),
      activityType: 'Pickleball',
      captain: _dave,
      audienceLabel: 'Paddle Kru',
      confirmedTime: 'Tomorrow 6pm',
      confirmedLocation: 'Alberta Park',
      goingCount: 5,
      threadMessageCount: 4,
    ),
  ];

  // Community event timelines, keyed by community name. Every item is a
  // born-confirmed recurring event broadcast by the community's leaders.
  late final Map<String, List<_TimelineItem>> communityEvents = {
    'Wednesday Night Rides': [
      _CommunityEventItem(
        id: 'evt_cherry_blossoms',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        community: _communities[0],
        title: 'Cherry Blossoms Ride',
        activityType: 'Biking',
        time: 'Wed Apr 1 · 6:30pm',
        recurrence: 'Every other Wed',
        location: 'Clark Park → Kelly Drive · 10.2mi · Easy',
        goingCount: 64,
        publicGoing: [_maya, _jordan, _alex, _rachel],
        threadMessageCount: 11,
      ),
      _CommunityEventItem(
        id: 'evt_protected_lanes',
        timestamp: DateTime.now().subtract(const Duration(days: 12)),
        community: _communities[0],
        title: 'West Philly Protected Lanes',
        activityType: 'Biking',
        time: 'Wed Apr 15 · 6:30pm',
        recurrence: 'Every other Wed',
        location: 'Dilworth Park · 7.4mi · Standard',
        goingCount: 38,
        publicGoing: [_dave, _sarah],
        threadMessageCount: 5,
      ),
    ],
    'Black Squirrel Club': [
      _CommunityEventItem(
        id: 'evt_jazz_jam',
        timestamp: DateTime.now().subtract(const Duration(hours: 8)),
        community: _communities[1],
        title: 'Monday Jazz Jam',
        activityType: 'Live Music',
        time: 'Mon · 7:00pm',
        recurrence: 'Weekly · Mondays',
        location: '1049 Sarah St, Fishtown',
        goingCount: 127,
        publicGoing: [_lisa, _mike, _katie, _john],
        threadMessageCount: 9,
      ),
      _CommunityEventItem(
        id: 'evt_samba',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        community: _communities[1],
        title: 'Roda de Samba e Choro',
        activityType: 'Live Music',
        time: 'Sat Jun 14 · 8:00pm',
        recurrence: 'One-off',
        location: '1049 Sarah St, Fishtown',
        goingCount: 73,
        publicGoing: [_rachel, _maya],
        threadMessageCount: 4,
      ),
    ],
    'Philly River Flow': [
      _CommunityEventItem(
        id: 'evt_riverside_vinyasa',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        community: _communities[2],
        title: 'Riverside Vinyasa',
        activityType: 'Yoga',
        time: 'Sat · 10:00am',
        recurrence: 'Tue / Thu / Sat / Sun',
        location: 'Schuylkill Banks · 25th & Locust · donation',
        goingCount: 41,
        publicGoing: [_sarah, _lisa, _jordan],
        threadMessageCount: 6,
      ),
    ],
  };

  // Thread mock data for the paddleboard idea
  final List<_ThreadMessage> paddleboardThreadMessages = [
    _ThreadMessage(
      sender: null,
      content: 'Lisa proposed paddleboarding',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      isSystem: true,
    ),
    _ThreadMessage(
      sender: _sarah,
      content: "I've always wanted to try this! Is gear provided?",
      timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 45)),
    ),
    _ThreadMessage(
      sender: _lisa,
      content: 'Yeah, the rental place includes boards and life vests!',
      timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
    ),
    _ThreadMessage(
      sender: _mike,
      content:
          'Sunday works better for me. The weather forecast looks perfect.',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    _ThreadMessage(
      sender: _john,
      content: null,
      photos: ['river_photo.jpg'],
      timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
    ),
    _ThreadMessage(
      sender: _john,
      content: "Here's what it looked like last time I went. So good!",
      timestamp: DateTime.now().subtract(const Duration(minutes: 44)),
    ),
  ];

  // Thread votes for paddleboard idea
  final List<_VoteOption> paddleboardTimeVotes = [
    _VoteOption(
      id: 'time_paddle_sat',
      label: 'Saturday 10am',
      voters: [_sarah, _mike, _alex],
    ),
    _VoteOption(
      id: 'time_paddle_sun',
      label: 'Sunday 2pm',
      voters: [_john, _lisa, _rachel, _dave, _katie],
    ),
  ];

  final List<_VoteOption> paddleboardLocationVotes = [
    _VoteOption(
      id: 'loc_paddle_willamette',
      label: 'Willamette River',
      voters: [_sarah, _mike, _john, _lisa],
    ),
  ];

  // Generic thread messages for other items
  final List<_ThreadMessage> genericThreadMessages = [
    _ThreadMessage(
      sender: _sarah,
      content: 'Sounds fun!',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    _ThreadMessage(
      sender: _mike,
      content: "Count me in, let's do it!",
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];

  // ========================================================================
  // Lifecycle
  // ========================================================================

  @override
  void initState() {
    super.initState();
    _timelineScrollController.addListener(() {
      final shouldShow = _timelineScrollController.position.pixels > 100;
      if (shouldShow != _showScrollToBottom) {
        setState(() => _showScrollToBottom = shouldShow);
      }
    });
  }

  @override
  void dispose() {
    _timelineScrollController.dispose();
    _messageController.dispose();
    threadMessageController.dispose();
    threadScrollController.dispose();
    super.dispose();
  }

  // ========================================================================
  // Helpers
  // ========================================================================

  bool get _isFriendsContext => _selectedContext == 'friends';

  bool get _isSquadContext => _squads.any((s) => s.name == _selectedContext);

  bool get _isCommunityContext =>
      _communities.any((c) => c.name == _selectedContext);

  _MockCommunity? get _currentCommunity =>
      _communities.where((c) => c.name == _selectedContext).firstOrNull;

  List<_TimelineItem> get _currentItems {
    if (_isFriendsContext) return friendsItems;
    if (_isCommunityContext) return communityEvents[_selectedContext] ?? [];
    return squadItems;
  }

  String get _currentTitle =>
      _isFriendsContext ? 'My Friends' : _selectedContext;

  String formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  void _scrollToBottom() {
    _timelineScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void openThread(String itemId) {
    setState(() {
      activeThreadItemId = itemId;
      _showSquadDropdown = false;
      showVotingExpanded = false;
    });
  }

  void closeThread() {
    setState(() {
      activeThreadItemId = null;
      threadMessageController.clear();
    });
  }

  void setResponse(String itemId, String response) {
    setState(() {
      userResponses[itemId] = response;
      expandedResponses.remove(itemId);
    });
  }

  void toggleExpandResponse(String itemId) {
    setState(() {
      if (expandedResponses.contains(itemId)) {
        expandedResponses.remove(itemId);
      } else {
        expandedResponses.add(itemId);
      }
    });
  }

  void toggleTimeVote(String voteId) {
    setState(() {
      if (userTimeVotes.contains(voteId)) {
        userTimeVotes.remove(voteId);
      } else {
        userTimeVotes.add(voteId);
      }
    });
  }

  void toggleLocationVote(String voteId) {
    setState(() {
      if (userLocationVotes.contains(voteId)) {
        userLocationVotes.remove(voteId);
      } else {
        userLocationVotes.add(voteId);
      }
    });
  }

  void toggleVotingExpanded() {
    setState(() => showVotingExpanded = !showVotingExpanded);
  }

  void _toggleIdeaComposer() {
    setState(() {
      _showIdeaComposer = !_showIdeaComposer;
      if (!_showIdeaComposer) {
        _selectedActivityType = null;
        _pendingEventRef = null;
      }
    });
  }

  // ========================================================================
  // Idea → Activity transition
  // ========================================================================

  /// Resolves a timeline item to its current state. A confirmed idea is
  /// promoted on the fly to an activity so all the existing activity rendering
  /// (timeline card + thread header) is reused — modeling the spec's
  /// "two states of the same record".
  _TimelineItem resolveItem(_TimelineItem item) {
    if (item is _IdeaItem && confirmedPlans.containsKey(item.id)) {
      final plan = confirmedPlans[item.id]!;
      return _ActivityItem(
        id: item.id,
        timestamp: item.timestamp,
        activityType: item.activityType,
        captain: item.captain,
        audienceLabel: item.audienceLabel,
        confirmedTime: plan.time,
        confirmedLocation: plan.location,
        goingCount: item.interestedCount,
        threadMessageCount: item.threadMessageCount,
        eventRef: item.eventRef,
      );
    }
    return item;
  }

  /// Captain locks in a time + location, promoting the idea to a confirmed
  /// activity.
  void confirmIdea(String ideaId, String time, String location) {
    setState(() {
      confirmedPlans[ideaId] = (time: time, location: location);
      showVotingExpanded = false;
    });
  }

  // ========================================================================
  // Community event RSVP (visibility gradient)
  // ========================================================================

  void toggleGoing(String eventId) {
    setState(() {
      if (goingEvents.contains(eventId)) {
        goingEvents.remove(eventId);
        publicEvents.remove(eventId); // can't be public if not going
      } else {
        goingEvents.add(eventId);
      }
    });
  }

  void togglePublic(String eventId) {
    setState(() {
      if (publicEvents.contains(eventId)) {
        publicEvents.remove(eventId);
      } else {
        publicEvents.add(eventId);
        goingEvents.add(eventId); // going publicly implies going
      }
    });
  }

  /// Bring friends to a community event: switch to the My Friends context and
  /// open the idea composer pre-filled with the event. What lands on the
  /// friends timeline is a friends-scoped idea referencing the public event —
  /// the event itself stays owned by the community.
  void bringFriendsToEvent(_CommunityEventItem event) {
    setState(() {
      activeThreadItemId = null;
      _selectedContext = 'friends';
      _showSquadDropdown = false;
      _selectedActivityType = event.activityType;
      _pendingEventRef = _EventRef(
        communityName: event.community.name,
        eventTitle: event.title,
        communityIcon: event.community.icon,
        communityColor: event.community.color,
        eventTime: event.time,
        eventLocation: event.location,
      );
      _showIdeaComposer = true;
    });
  }

  int _newIdeaSeq = 0;

  /// Posts the composed idea to the current timeline. If an event was staged
  /// via "bring friends", the new idea carries the embedded event reference.
  void _shareIdea() {
    final type = _selectedActivityType;
    if (type == null) return;

    // Destination is always the current context — the bring-friends selector
    // and the title-bar selector both drive _selectedContext, so the feed
    // behind the composer is the feed you're posting into.
    final toSquad = _isSquadContext;

    final newIdea = _IdeaItem(
      id: 'idea_new_${_newIdeaSeq++}',
      timestamp: DateTime.now(),
      activityType: type,
      captain: _you,
      audienceLabel: toSquad ? _selectedContext : 'all friends',
      proposedTimes: const [],
      proposedLocations: const [],
      allowSuggestions: _pendingEventRef == null,
      interestedCount: 0,
      threadMessageCount: 0,
      eventRef: _pendingEventRef,
    );

    setState(() {
      (toSquad ? squadItems : friendsItems).add(newIdea);
      _showIdeaComposer = false;
      _selectedActivityType = null;
      _pendingEventRef = null;
    });

    // Jump to the newest item.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_timelineScrollController.hasClients) _scrollToBottom();
    });
  }

  // ========================================================================
  // Build
  // ========================================================================

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppScaffold(
      showAppBar: false,
      body: Stack(
        children: [
          // Main content layer
          Column(
            children: [
              _buildCustomAppBar(colorScheme),
              Expanded(
                child: Stack(
                  children: [
                    _buildTimeline(colorScheme),
                    if (_showScrollToBottom)
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FloatingActionButton.small(
                          onPressed: _scrollToBottom,
                          child: const Icon(Icons.keyboard_arrow_down),
                        ),
                      ),
                    if (_showSquadDropdown) _buildSquadDropdown(colorScheme),
                  ],
                ),
              ),
              _buildInputArea(colorScheme),
            ],
          ),

          // Thread scrim (covers everything)
          if (activeThreadItemId != null)
            Positioned.fill(
              child: GestureDetector(
                onTap: closeThread,
                child: Container(
                  color: Colors.black.withAlpha(80),
                ),
              ),
            ),

          // Thread drawer (covers everything)
          buildThreadDrawer(colorScheme),
        ],
      ),
    );
  }

  // ========================================================================
  // Custom App Bar
  // ========================================================================

  Widget _buildCustomAppBar(ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              setState(() => _showSquadDropdown = !_showSquadDropdown);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isSquadContext)
                  Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        _currentTitle[0],
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                else if (_isCommunityContext && _currentCommunity != null)
                  Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: _currentCommunity!.color.withAlpha(40),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _currentCommunity!.icon,
                      size: 16,
                      color: _currentCommunity!.color,
                    ),
                  ),
                Text(
                  _currentTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _showSquadDropdown ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // ========================================================================
  // Squad Dropdown
  // ========================================================================

  Widget _buildSquadDropdown(ColorScheme colorScheme) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDropdownItem(
              icon: Icons.people_outline,
              label: 'My Friends',
              subtitle: 'Everyone you\'re connected with',
              isSelected: _isFriendsContext,
              onTap: () {
                setState(() {
                  _selectedContext = 'friends';
                  _showSquadDropdown = false;
                });
              },
              colorScheme: colorScheme,
            ),
            _buildDropdownDivider(colorScheme),

            // Squads — closed groups where everyone posts
            _buildDropdownSectionHeader('SQUADS', colorScheme),
            ..._squads.map((squad) => _buildDropdownItem(
                  icon: Icons.group,
                  label: squad.name,
                  subtitle: '${squad.memberCount} members',
                  isSelected: _selectedContext == squad.name,
                  onTap: () {
                    setState(() {
                      _selectedContext = squad.name;
                      _showSquadDropdown = false;
                    });
                  },
                  colorScheme: colorScheme,
                )),

            _buildDropdownDivider(colorScheme),

            // Communities — open groups you follow; leaders broadcast events
            _buildDropdownSectionHeader('COMMUNITIES', colorScheme),
            ..._communities.map((community) => _buildDropdownItem(
                  icon: community.icon,
                  label: community.name,
                  subtitle: '${community.followerCount} following',
                  isSelected: _selectedContext == community.name,
                  iconColor: community.color,
                  onTap: () {
                    setState(() {
                      _selectedContext = community.name;
                      _showSquadDropdown = false;
                    });
                  },
                  colorScheme: colorScheme,
                )),
            _buildDropdownItem(
              icon: Icons.travel_explore,
              label: 'Discover communities',
              subtitle: 'Find groups near you',
              isSelected: false,
              onTap: () {
                setState(() => _showSquadDropdown = false);
              },
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownDivider(ColorScheme colorScheme) => Divider(
        height: 1,
        indent: 16,
        endIndent: 16,
        color: colorScheme.outlineVariant,
      );

  Widget _buildDropdownSectionHeader(String label, ColorScheme colorScheme) =>
      Padding(
        padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      );

  Widget _buildDropdownItem({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
    Color? iconColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? colorScheme.primary
                    : (iconColor ?? colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check, size: 18, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  // ========================================================================
  // Timeline
  // ========================================================================

  Widget _buildTimeline(ColorScheme colorScheme) {
    final items = _currentItems;

    return ListView.builder(
      controller: _timelineScrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = resolveItem(items[items.length - 1 - index]);

        return switch (item) {
          _IdeaItem() => buildIdeaCard(item, colorScheme),
          _ActivityItem() => buildActivityCard(item, colorScheme),
          _SquadTextMessage() => buildSquadMessage(item, colorScheme),
          _CommunityEventItem() => buildCommunityEventCard(item, colorScheme),
        };
      },
    );
  }

  // ========================================================================
  // Unified Input Area
  // ========================================================================

  Widget _buildInputArea(ColorScheme colorScheme) {
    // Communities are broadcast-only: followers don't post to the timeline,
    // so there's no composer — just a banner reinforcing the read-only context.
    if (_isCommunityContext) {
      return _buildFollowerBanner(colorScheme);
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Idea composer panel (slides up when active)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _showIdeaComposer
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: _buildIdeaComposer(colorScheme),
            secondChild: const SizedBox.shrink(),
          ),

          // Audience indicator
          _buildMainAudienceIndicator(colorScheme),

          // Input bar
          Padding(
            padding: const EdgeInsets.all(8),
            child: _isSquadContext
                ? Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.photo_outlined),
                        onPressed: () {},
                        color: colorScheme.onSurfaceVariant,
                        iconSize: 22,
                      ),
                      IconButton(
                        icon: Icon(
                          _showIdeaComposer
                              ? Icons.lightbulb
                              : Icons.lightbulb_outline,
                        ),
                        onPressed: _toggleIdeaComposer,
                        color: _showIdeaComposer
                            ? colorScheme.tertiary
                            : colorScheme.onSurfaceVariant,
                        iconSize: 22,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Message $_currentTitle...',
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          minLines: 1,
                          maxLines: 4,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.send),
                        color: colorScheme.primary,
                        iconSize: 22,
                      ),
                    ],
                  )
                : GestureDetector(
                    onTap: _toggleIdeaComposer,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _showIdeaComposer
                                ? Icons.lightbulb
                                : Icons.lightbulb_outline,
                            size: 20,
                            color: _showIdeaComposer
                                ? colorScheme.tertiary
                                : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Share an idea...',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // Audience Indicator (main input)
  // ========================================================================

  Widget _buildMainAudienceIndicator(ColorScheme colorScheme) {
    final IconData icon;
    final String text;

    if (_showIdeaComposer) {
      icon = Icons.visibility_outlined;
      if (_pendingEventRef != null) {
        final dest = _isSquadContext ? _selectedContext : 'all friends';
        text =
            'Sharing with $dest · about a ${_pendingEventRef!.communityName} event';
      } else {
        text = _isSquadContext
            ? 'This idea will be shared with $_currentTitle'
            : 'This idea will be shared with all your friends';
      }
    } else if (_isSquadContext) {
      icon = Icons.group_outlined;
      text = 'Visible to $_currentTitle members';
    } else {
      icon = Icons.people_outline;
      text = 'Your friends see your ideas · threads are private';
    }

    return buildAudienceIndicator(colorScheme, icon: icon, text: text);
  }

  // ========================================================================
  // Idea Composer
  // ========================================================================

  static const _activityTypes = [
    'Hiking',
    'Pickleball',
    'Board Games',
    'Rock Climbing',
    'Paddleboarding',
    'Picnic',
    'Tennis',
    'Biking',
    'Yoga',
    'Cooking',
    'Movie Night',
    'Beach',
  ];

  Widget _buildIdeaComposer(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colorScheme.tertiary.withAlpha(60), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label
          Row(
            children: [
              Icon(Icons.lightbulb_outline,
                  size: 15, color: colorScheme.tertiary),
              const SizedBox(width: 6),
              Text(
                _pendingEventRef != null ? 'Bring friends' : 'Share an idea',
                style: TextStyle(
                  color: colorScheme.tertiary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Attached community event (when bringing friends along)
          if (_pendingEventRef != null) ...[
            _buildComposerEventChip(_pendingEventRef!, colorScheme),
            const SizedBox(height: 10),
          ],

          // Activity type picker (horizontal scroll)
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _activityTypes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final type = _activityTypes[index];
                final isSelected = _selectedActivityType == type;
                return GestureDetector(
                  onTap: () {
                    setState(
                        () => _selectedActivityType = isSelected ? null : type);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.tertiary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.tertiary
                            : colorScheme.outlineVariant,
                      ),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(
                        color: isSelected
                            ? colorScheme.onTertiary
                            : colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          // Bring-friends: pick where to post (My Friends or a squad). The
          // event already fixes time/place, so no add-times/locations options.
          if (_pendingEventRef != null) ...[
            _buildAudienceSelector(colorScheme),
            const SizedBox(height: 10),
          ],

          Row(
            children: [
              // Add times/locations only apply when proposing a fresh idea.
              if (_pendingEventRef == null) ...[
                _buildIdeaOptionChip(
                  Icons.schedule_outlined,
                  'Add times',
                  colorScheme,
                ),
                const SizedBox(width: 8),
                _buildIdeaOptionChip(
                  Icons.location_on_outlined,
                  'Add locations',
                  colorScheme,
                ),
              ],
              const Spacer(),
              // Share button
              FilledButton.tonal(
                onPressed: _selectedActivityType != null ? _shareIdea : null,
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.tertiary,
                  foregroundColor: colorScheme.onTertiary,
                  disabledBackgroundColor: colorScheme.tertiary.withAlpha(40),
                  disabledForegroundColor: colorScheme.tertiary.withAlpha(100),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  minimumSize: const Size(0, 34),
                ),
                child: const Text('Share', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  /// Destination picker shown in the bring-friends composer: post the
  /// brought-along idea to My Friends or to one of your squads. Selecting here
  /// switches the view too, so the feed behind the composer is the destination.
  Widget _buildAudienceSelector(ColorScheme colorScheme) {
    Widget chip(String value, String label, IconData icon) {
      final selected = _selectedContext == value;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: GestureDetector(
          onTap: () => setState(() => _selectedContext = value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? colorScheme.tertiary : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? colorScheme.tertiary
                    : colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 13,
                    color: selected
                        ? colorScheme.onTertiary
                        : colorScheme.onSurfaceVariant),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? colorScheme.onTertiary
                        : colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Post to',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 30,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              chip('friends', 'My Friends', Icons.people_outline),
              ..._squads.map((s) => chip(s.name, s.name, Icons.group)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIdeaOptionChip(
      IconData icon, String label, ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Read-only event reference shown inside the idea composer when bringing
  /// friends to a community event — the event's time/place are fixed, so this
  /// just anchors the idea to the public event.
  Widget _buildComposerEventChip(_EventRef ref, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ref.communityColor.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ref.communityColor.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(ref.communityIcon, size: 16, color: ref.communityColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ref.eventTitle,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  ref.communityName,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.link, size: 14, color: colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }

  /// Communities are broadcast-only — followers see events but don't post.
  Widget _buildFollowerBanner(ColorScheme colorScheme) {
    final community = _currentCommunity;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 12 + MediaQuery.of(context).padding.bottom,
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle,
                size: 18, color: community?.color ?? colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Following · only leaders post events here',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('Following', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}
