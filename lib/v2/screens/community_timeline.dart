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

final _katie = _MockPerson(name: 'Katie', initial: 'K', color: Colors.pink);
final _mike = _MockPerson(name: 'Mike', initial: 'M', color: Colors.blue);
final _sarah = _MockPerson(name: 'Sarah', initial: 'S', color: Colors.orange);
final _lisa = _MockPerson(name: 'Lisa', initial: 'L', color: Colors.purple);
final _john = _MockPerson(name: 'John', initial: 'J', color: Colors.green);
final _alex = _MockPerson(name: 'Alex', initial: 'A', color: Colors.teal);
final _rachel = _MockPerson(name: 'Rachel', initial: 'R', color: Colors.red);
final _dave = _MockPerson(name: 'Dave', initial: 'D', color: Colors.indigo);

// ============================================================================
// Mock Squads
// ============================================================================

final _squads = [
  _MockSquad(name: 'Paddle Kru', memberCount: 8),
  _MockSquad(name: 'Weekend Hikers', memberCount: 12),
  _MockSquad(name: 'Game Night Crew', memberCount: 5),
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

  // Context selection
  String _selectedContext = 'community';
  bool _showSquadDropdown = false;

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

  late final List<_TimelineItem> communityItems = [
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

  List<_TimelineItem> get _currentItems =>
      _selectedContext == 'community' ? communityItems : squadItems;

  bool get _isSquadContext => _selectedContext != 'community';

  String get _currentTitle =>
      _selectedContext == 'community' ? 'My Community' : _selectedContext;

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
      }
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
              label: 'My Community',
              subtitle: 'All friends',
              isSelected: _selectedContext == 'community',
              onTap: () {
                setState(() {
                  _selectedContext = 'community';
                  _showSquadDropdown = false;
                });
              },
              colorScheme: colorScheme,
            ),
            Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: colorScheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
              child: Row(
                children: [
                  Text(
                    'SQUADS',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownItem({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
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
                    : colorScheme.onSurfaceVariant,
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
        final item = items[items.length - 1 - index];

        return switch (item) {
          _IdeaItem() => buildIdeaCard(item, colorScheme),
          _ActivityItem() => buildActivityCard(item, colorScheme),
          _SquadTextMessage() => buildSquadMessage(item, colorScheme),
        };
      },
    );
  }

  // ========================================================================
  // Unified Input Area
  // ========================================================================

  Widget _buildInputArea(ColorScheme colorScheme) {
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
      text = _isSquadContext
          ? 'This idea will be shared with $_currentTitle'
          : 'This idea will be shared with all your friends';
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
                'Share an idea',
                style: TextStyle(
                  color: colorScheme.tertiary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

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

          // Optional: add times/locations
          Row(
            children: [
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
              const Spacer(),
              // Share button
              FilledButton.tonal(
                onPressed: _selectedActivityType != null
                    ? () {
                        setState(() {
                          _showIdeaComposer = false;
                          _selectedActivityType = null;
                        });
                      }
                    : null,
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
}
