import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storybook_toolkit/storybook_toolkit.dart';
import 'package:squadquest/app_scaffold.dart';

class EventChatScreen extends ConsumerStatefulWidget {
  const EventChatScreen({super.key});

  @override
  ConsumerState<EventChatScreen> createState() => _EventChatScreenState();
}

class _EventChatScreenState extends ConsumerState<EventChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottom = false;
  bool _isPinned = false;

  final List<_MockMessage> _messages = [
    _MockMessage(
      sender: 'Sarah Chen',
      content: 'Hey everyone! Looking forward to game night!',
      time: DateTime.now().subtract(const Duration(days: 2, hours: 3)),
      isHost: true,
    ),
    _MockMessage(
      sender: 'Sarah Chen',
      content: 'I\'ll bring some extra games just in case.',
      time: DateTime.now().subtract(const Duration(days: 2, hours: 3)),
      isHost: true,
    ),
    _MockMessage(
      sender: 'Mike Rodriguez',
      content: 'Me too! I\'ll bring Catan and Ticket to Ride.',
      time: DateTime.now().subtract(const Duration(days: 2, hours: 2)),
    ),
    _MockMessage(
      sender: 'Mike Rodriguez',
      content: 'And maybe Splendor if we have time.',
      time: DateTime.now().subtract(const Duration(days: 2, hours: 2)),
    ),
    _MockMessage(
      sender: 'Sarah Chen',
      content:
          '📌 IMPORTANT: We\'ll be in the back room, look for the SquadQuest sign!',
      time: DateTime.now().subtract(const Duration(days: 1, hours: 23)),
      isHost: true,
      isPinned: true,
    ),
    _MockMessage(
      sender: 'John Smith',
      content: 'Anyone up for Pandemic? I just got the legacy version!',
      time: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    _MockMessage(
      sender: 'Sarah Chen',
      content: 'That sounds fun! We can definitely try it out.',
      time: DateTime.now().subtract(const Duration(hours: 4)),
      isHost: true,
    ),
    _MockMessage(
      sender: 'Sarah Chen',
      content: 'I\'ve been wanting to play that one.',
      time: DateTime.now().subtract(const Duration(hours: 4)),
      isHost: true,
    ),
    _MockMessage(
      sender: 'Lisa Wong',
      content: 'Running a bit late, save me a spot!',
      time: DateTime.now().subtract(const Duration(minutes: 30)),
    ),
    _MockMessage(
      sender: 'Lisa Wong',
      content: 'Traffic is terrible today.',
      time: DateTime.now().subtract(const Duration(minutes: 30)),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      setState(() {
        _showScrollToBottom = _scrollController.position.pixels > 100;
      });
    });
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _sendMessage(bool isHost) {
    if (_messageController.text.trim().isEmpty) return;

    setState(() {
      _messages.add(_MockMessage(
        sender: isHost ? 'Sarah Chen' : 'You',
        content: _messageController.text.trim(),
        time: DateTime.now(),
        isHost: isHost,
        isPinned: isHost && _isPinned,
      ));
      _messageController.clear();
      _isPinned = false;
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

  @override
  Widget build(BuildContext context) {
    final isHost = context.knobs.boolean(
      label: 'I\'m the host',
      initial: false,
      description: 'Toggle to see host-specific features',
    );

    return AppScaffold(
      title: 'Board Game Night Chat',
      body: Stack(
        children: [
          Column(
            children: [
              // Event Status Banner
              Container(
                padding: const EdgeInsets.all(8),
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Row(
                  children: [
                    const Icon(Icons.event_available, size: 20),
                    const SizedBox(width: 8),
                    const Text('Saturday at 7:00 PM'),
                    const Spacer(),
                    TextButton(
                      onPressed: () {},
                      child: const Text('View Event'),
                    ),
                  ],
                ),
              ),

              // Chat Messages
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
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

                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: isLastInGroup ? 16 : 2,
                      ),
                      child: Column(
                        crossAxisAlignment: message.sender == 'You'
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          if (isFirstInGroup) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 12, right: 12, bottom: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    message.sender,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: message.isHost
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : null,
                                    ),
                                  ),
                                  if (message.isHost) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.star,
                                      size: 14,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                          Row(
                            mainAxisAlignment: message.sender == 'You'
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            children: [
                              if (message.sender != 'You' && !isFirstInGroup)
                                const SizedBox(width: 40),
                              Container(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.75,
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: message.isPinned
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                      : message.sender == 'You'
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Theme.of(context)
                                              .colorScheme
                                              .surfaceVariant,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(
                                        message.sender != 'You' &&
                                                !isFirstInGroup
                                            ? 5
                                            : 20),
                                    topRight: Radius.circular(
                                        message.sender == 'You' &&
                                                !isFirstInGroup
                                            ? 5
                                            : 20),
                                    bottomLeft: const Radius.circular(20),
                                    bottomRight: const Radius.circular(20),
                                  ),
                                ),
                                child: Text(
                                  message.content,
                                  style: TextStyle(
                                    color: message.isPinned
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer
                                        : message.sender == 'You'
                                            ? Colors.white
                                            : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isLastInGroup)
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 12, right: 12, top: 4),
                              child: Text(
                                _formatTime(message.time),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Message Input
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      if (isHost && _isPinned)
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.push_pin),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                    'This message will be pinned as an announcement'),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    setState(() => _isPinned = false),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          if (isHost)
                            IconButton(
                              icon: Icon(
                                Icons.push_pin,
                                color: _isPinned
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                              onPressed: () =>
                                  setState(() => _isPinned = !_isPinned),
                            ),
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: InputDecoration(
                                hintText: 'Type a message...',
                                filled: true,
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceVariant,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                              maxLines: null,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _sendMessage(isHost),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _sendMessage(isHost),
                            icon: const Icon(Icons.send),
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Scroll to Bottom Button
          if (_showScrollToBottom)
            Positioned(
              right: 16,
              bottom: 80,
              child: FloatingActionButton.small(
                onPressed: _scrollToBottom,
                child: const Icon(Icons.keyboard_arrow_down),
              ),
            ),
        ],
      ),
    );
  }
}

class _MockMessage {
  final String sender;
  final String content;
  final DateTime time;
  final bool isHost;
  final bool isPinned;

  _MockMessage({
    required this.sender,
    required this.content,
    required this.time,
    this.isHost = false,
    this.isPinned = false,
  });
}
