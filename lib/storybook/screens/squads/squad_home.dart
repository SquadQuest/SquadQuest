import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadquest/app_scaffold.dart';

class SquadHomeScreen extends ConsumerStatefulWidget {
  const SquadHomeScreen({super.key});

  @override
  ConsumerState<SquadHomeScreen> createState() => _SquadHomeScreenState();
}

class _SquadHomeScreenState extends ConsumerState<SquadHomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final ScrollController _calendarScrollController = ScrollController();
  bool _showScrollToBottom = false;
  int _eventsAfterVisible = 0;
  int? _selectedDayIndex; // null = no selection

  // Constants for calendar layout
  static const double _dayTileWidth = 52;
  static const double _dayTileMargin = 4;
  static const double _calendarPadding = 8;

  // Mock squad data
  final String _squadName = 'Paddle Kru';
  final int _memberCount = 8;

  // Mock calendar data with events and ideas
  late final List<_CalendarDay> _calendarDays = List.generate(14, (index) {
    final date = DateTime.now().add(Duration(days: index));
    List<_MockEvent> events = [];
    List<_MockEventIdea> ideas = [];

    // Add some mock events and ideas
    if (index == 0) {
      events = [
        _MockEvent(title: 'Paddle Session', time: '6:00 PM', attendeeCount: 5),
      ];
    } else if (index == 2) {
      events = [
        _MockEvent(title: 'Morning Paddle', time: '7:00 AM', attendeeCount: 3),
        _MockEvent(title: 'Evening Games', time: '7:00 PM', attendeeCount: 6),
      ];
    } else if (index == 4) {
      ideas = [
        _MockEventIdea(
            title: 'Beach Volleyball?', proposedBy: 'Sarah', votes: 4),
      ];
    } else if (index == 7) {
      events = [
        _MockEvent(
            title: 'Weekend Tournament', time: '10:00 AM', attendeeCount: 8),
      ];
    } else if (index == 10) {
      ideas = [
        _MockEventIdea(
            title: 'Try new courts downtown', proposedBy: 'Mike', votes: 3),
      ];
    } else if (index == 12) {
      events = [
        _MockEvent(title: 'Paddle & Brunch', time: '9:00 AM', attendeeCount: 6),
        _MockEvent(title: 'Sunset Session', time: '5:30 PM', attendeeCount: 4),
      ];
    }

    final eventCount =
        events.isNotEmpty || ideas.isNotEmpty ? events.length + ideas.length : null;
    final hasIdea = ideas.isNotEmpty;

    return _CalendarDay(
      date: date,
      eventCount: eventCount,
      hasIdea: hasIdea,
      events: events,
      ideas: ideas,
    );
  });

  // Mock chat messages
  final List<_MockMessage> _messages = [
    _MockMessage(
      sender: 'Sarah',
      content: 'Great paddle session yesterday! 🏓',
      time: DateTime.now().subtract(const Duration(days: 1, hours: 5)),
    ),
    _MockMessage(
      sender: 'Mike',
      content: 'Yeah that was fun! We should do it again soon.',
      time: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
    ),
    _MockMessage(
      sender: 'Mike',
      content: 'Maybe this weekend?',
      time: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
    ),
    _MockMessage(
      sender: 'Lisa',
      content: 'I\'m in! Saturday works for me.',
      time: DateTime.now().subtract(const Duration(hours: 20)),
    ),
    _MockMessage(
      sender: 'Sarah',
      content: 'Should we try that new place downtown?',
      time: DateTime.now().subtract(const Duration(hours: 18)),
    ),
    _MockMessage(
      sender: 'John',
      content: 'Which one? The one with the outdoor courts?',
      time: DateTime.now().subtract(const Duration(hours: 16)),
    ),
    _MockMessage(
      sender: 'Sarah',
      content: 'Yeah! They have 8 courts and a bar 🍻',
      time: DateTime.now().subtract(const Duration(hours: 15)),
    ),
    _MockMessage(
      sender: 'Mike',
      content: 'Sounds perfect. Anyone up for paddle tomorrow?',
      time: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    _MockMessage(
      sender: 'Lisa',
      content: 'Count me in!',
      time: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _chatScrollController.addListener(() {
      setState(() {
        _showScrollToBottom = _chatScrollController.position.pixels > 100;
      });
    });
    _calendarScrollController.addListener(_updateEventsCount);

    // Calculate initial count after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateEventsCount());
  }

  void _updateEventsCount() {
    if (!_calendarScrollController.hasClients) return;

    final position = _calendarScrollController.position;
    final scrollOffset = position.pixels;
    final viewportWidth = position.viewportDimension;

    // Each tile takes 60px (52 width + 8 margin total)
    final tileFullWidth = _dayTileWidth + (_dayTileMargin * 2);

    // Calculate which tile index is at the right edge of the visible area
    // Reserve space for the indicator (52px) and padding (8px)
    final visibleWidth = viewportWidth - 52 - _calendarPadding;
    final lastVisibleIndex =
        ((scrollOffset + visibleWidth) / tileFullWidth).floor();

    // Sum events for days beyond the last visible index
    int count = 0;
    for (int i = lastVisibleIndex + 1; i < _calendarDays.length; i++) {
      if (_calendarDays[i].eventCount != null) {
        count += _calendarDays[i].eventCount!;
      }
    }

    if (count != _eventsAfterVisible) {
      setState(() {
        _eventsAfterVisible = count;
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _chatScrollController.dispose();
    _calendarScrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    _chatScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    setState(() {
      _messages.add(_MockMessage(
        sender: 'You',
        content: _messageController.text.trim(),
        time: DateTime.now(),
      ));
      _messageController.clear();
    });

    _scrollToBottom();
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String _getWeekdayAbbr(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppScaffold(
      title: _squadName,
      actions: [
        // Members badge
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.people),
              onPressed: () {},
            ),
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Text(
                  '$_memberCount',
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
      body: Column(
        children: [
          // Calendar Strip
          _buildCalendarStrip(colorScheme),

          // Chat Messages with Day Detail Drawer overlay
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
                  controller: _chatScrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[_messages.length - 1 - index];
                    final previousMessage = index < _messages.length - 1
                        ? _messages[_messages.length - 2 - index]
                        : null;
                    final nextMessage =
                        index > 0 ? _messages[_messages.length - index] : null;

                    final isFirstInGroup =
                        previousMessage?.sender != message.sender;
                    final isLastInGroup = nextMessage?.sender != message.sender;

                    return _buildMessageBubble(
                      message,
                      isFirstInGroup,
                      isLastInGroup,
                      colorScheme,
                    );
                  },
                ),

                // Day Detail Drawer
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildDayDetailDrawer(colorScheme),
                ),

                // Scroll to Bottom Button
                if (_showScrollToBottom)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton.small(
                      onPressed: _scrollToBottom,
                      child: const Icon(Icons.keyboard_arrow_down),
                    ),
                  ),
              ],
            ),
          ),

          // Message Input
          _buildMessageInput(colorScheme),
        ],
      ),
    );
  }

  Widget _buildCalendarStrip(ColorScheme colorScheme) {
    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ListView.builder(
            controller: _calendarScrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            itemCount: _calendarDays.length,
            itemBuilder: (context, index) {
              final day = _calendarDays[index];
              final isToday = index == 0;
              final isSelected = index == _selectedDayIndex;
              return _buildDayTile(day, index, isToday, isSelected, colorScheme);
            },
          ),
          // Right edge indicator with slide animation
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 200),
              offset:
                  _eventsAfterVisible > 0 ? Offset.zero : const Offset(1, 0),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _eventsAfterVisible > 0 ? 1.0 : 0.0,
                child: Container(
                  width: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        colorScheme.surfaceContainerHighest.withAlpha(0),
                        colorScheme.surfaceContainerHighest,
                      ],
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$_eventsAfterVisible+',
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 14,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayDetailDrawer(ColorScheme colorScheme) {
    final isOpen = _selectedDayIndex != null;
    final day = isOpen ? _calendarDays[_selectedDayIndex!] : null;

    return AnimatedSlide(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      offset: isOpen ? Offset.zero : const Offset(0, -1),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isOpen ? 1.0 : 0.0,
        child: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(40),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: day == null
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Events section
                    if (day.events.isNotEmpty) ...[
                      Text(
                        'Events',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...day.events.map((event) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        event.title,
                                        style: TextStyle(
                                          color: colorScheme.onSurface,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '${event.time} · ${event.attendeeCount} going',
                                        style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          )),
                    ],

                    // Ideas section
                    if (day.ideas.isNotEmpty) ...[
                      if (day.events.isNotEmpty) const SizedBox(height: 8),
                      Text(
                        'Ideas Being Polled',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...day.ideas.map((idea) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(2),
                                    border: Border.all(
                                      color: colorScheme.tertiary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        idea.title,
                                        style: TextStyle(
                                          color: colorScheme.onSurface,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Proposed by ${idea.proposedBy} · ${idea.votes} votes',
                                        style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.how_to_vote_outlined,
                                  color: colorScheme.tertiary,
                                ),
                              ],
                            ),
                          )),
                    ],

                    // Empty state
                    if (day.events.isEmpty && day.ideas.isEmpty)
                      Center(
                        child: Text(
                          'No events or ideas for this day',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildDayTile(
    _CalendarDay day,
    int index,
    bool isToday,
    bool isSelected,
    ColorScheme colorScheme,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDayIndex = _selectedDayIndex == index ? null : index;
        });
      },
      child: Container(
        width: 52,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Main tile
            Positioned.fill(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHigh,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top section: Weekday + Day number
                  Column(
                    children: [
                      Text(
                        _getWeekdayAbbr(day.date),
                        style: TextStyle(
                          color: isSelected
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${day.date.day}',
                        style: TextStyle(
                          color: isSelected
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),

                  // Bottom section: Event badge
                  if (day.eventCount != null)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: day.hasIdea
                                  ? Colors.transparent
                                  : colorScheme.primary,
                              shape: BoxShape.circle,
                              border: day.hasIdea
                                  ? Border.all(
                                      color: colorScheme.primary, width: 1.5)
                                  : null,
                            ),
                          ),
                          Text(
                            '${day.eventCount}',
                            style: TextStyle(
                              color: day.hasIdea
                                  ? colorScheme.primary
                                  : colorScheme.onPrimary,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox(height: 14),
                ],
              ),
            ),
            ),

            // Today badge overlay at top
            if (isToday)
              Positioned(
                top: -4,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Today',
                      style: TextStyle(
                        color: colorScheme.onTertiary,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    _MockMessage message,
    bool isFirstInGroup,
    bool isLastInGroup,
    ColorScheme colorScheme,
  ) {
    final isMe = message.sender == 'You';

    return Padding(
      padding: EdgeInsets.only(
        bottom: isLastInGroup ? 16 : 2,
      ),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (isFirstInGroup && !isMe) ...[
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 4),
              child: Text(
                message.sender,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe && !isFirstInGroup) const SizedBox(width: 40),
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isMe
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(!isMe && !isFirstInGroup ? 5 : 20),
                    topRight: Radius.circular(isMe && !isFirstInGroup ? 5 : 20),
                    bottomLeft: const Radius.circular(20),
                    bottomRight: const Radius.circular(20),
                  ),
                ),
                child: Text(
                  message.content,
                  style: TextStyle(
                    color: isMe ? colorScheme.onPrimary : null,
                  ),
                ),
              ),
            ],
          ),
          if (isLastInGroup)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, top: 4),
              child: Text(
                _formatTime(message.time),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(8),
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
      child: SafeArea(
        child: Row(
          children: [
            // Attach button
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: () {},
            ),
            // Message input
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Message...',
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
                textInputAction: TextInputAction.newline,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            // Send button
            IconButton(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send),
              color: colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarDay {
  final DateTime date;
  final int? eventCount;
  final bool hasIdea;
  final List<_MockEvent> events;
  final List<_MockEventIdea> ideas;

  _CalendarDay({
    required this.date,
    this.eventCount,
    this.hasIdea = false,
    this.events = const [],
    this.ideas = const [],
  });
}

class _MockEvent {
  final String title;
  final String time;
  final int attendeeCount;

  _MockEvent({
    required this.title,
    required this.time,
    required this.attendeeCount,
  });
}

class _MockEventIdea {
  final String title;
  final String proposedBy;
  final int votes;

  _MockEventIdea({
    required this.title,
    required this.proposedBy,
    required this.votes,
  });
}

class _MockMessage {
  final String sender;
  final String content;
  final DateTime time;

  _MockMessage({
    required this.sender,
    required this.content,
    required this.time,
  });
}
