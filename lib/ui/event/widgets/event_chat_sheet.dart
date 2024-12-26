import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/controllers/chat.dart';
import 'package:squadquest/controllers/instances.dart';
import 'package:squadquest/controllers/auth.dart';

import 'package:squadquest/ui/core/widgets/app_bottom_sheet.dart';

class EventChatSheet extends ConsumerStatefulWidget {
  final InstanceID eventId;
  final double? height;

  const EventChatSheet({
    super.key,
    required this.eventId,
    this.height,
  });

  @override
  ConsumerState<EventChatSheet> createState() => _EventChatSheetState();
}

class _EventChatSheetState extends ConsumerState<EventChatSheet> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottom = false;
  bool _isPinned = false;

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

  Future<void> _sendMessage(bool isHost) async {
    final content = _messageController.text.trim();

    if (content.isEmpty) {
      return;
    }

    final chatController = ref.read(chatProvider(widget.eventId).notifier);

    try {
      await chatController.post(
        content,
        pinned: isHost && _isPinned,
      );
      _messageController.clear();
      _isPinned = false;
      _scrollToBottom();
    } catch (error, stackTrace) {
      logger.e('Failed to send message', error: error, stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatProvider(widget.eventId));
    final eventAsync = ref.watch(eventDetailsProvider(widget.eventId));
    final currentUserId = ref.read(authControllerProvider)!.user.id;

    final messages = messagesAsync.value ?? [];

    return AppBottomSheet(
      height: widget.height,
      title: eventAsync.value != null
          ? 'Chat: ${eventAsync.value!.title}'
          : 'Chat',
      children: [
        Expanded(
          child: Stack(
            children: [
              Column(
                children: [
                  // Messages
                  if (messagesAsync.isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(child: RefreshProgressIndicator()),
                    ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.all(8),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final previousMessage = index < messages.length - 1
                            ? messages[index + 1]
                            : null;
                        final nextMessage =
                            index > 0 ? messages[index - 1] : null;

                        final isFirstInGroup = previousMessage?.createdBy?.id !=
                            message.createdBy?.id;
                        final isLastInGroup =
                            nextMessage?.createdBy?.id != message.createdBy?.id;
                        final isMe = message.createdBy?.id == currentUserId;
                        final isHost = message.createdBy?.id ==
                            eventAsync.value?.createdBy?.id;

                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: isLastInGroup ? 16 : 2,
                          ),
                          child: Column(
                            crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              if (isFirstInGroup)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 12, right: 12, bottom: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundImage:
                                            message.createdBy?.photo != null
                                                ? NetworkImage(message
                                                    .createdBy!.photo
                                                    .toString())
                                                : null,
                                        child: message.createdBy?.photo == null
                                            ? const Icon(Icons.person, size: 16)
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        message.createdBy!.displayName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isHost
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : null,
                                        ),
                                      ),
                                      if (isHost) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.star,
                                          size: 14,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              if (message.pinned)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 12, right: 12, bottom: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Text('📌 Announcement',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              Row(
                                mainAxisAlignment: isMe
                                    ? MainAxisAlignment.end
                                    : MainAxisAlignment.start,
                                children: [
                                  if (!isMe && !isFirstInGroup)
                                    const SizedBox(width: 40),
                                  Container(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                              0.75,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: message.pinned
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primaryContainer
                                          : isMe
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withAlpha(175)
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(
                                            !isMe && !isFirstInGroup ? 5 : 20),
                                        topRight: Radius.circular(
                                            isMe && !isFirstInGroup ? 5 : 20),
                                        bottomLeft: const Radius.circular(20),
                                        bottomRight: const Radius.circular(20),
                                      ),
                                    ),
                                    child: Text(
                                      message.content,
                                      style: TextStyle(
                                        color: message.pinned
                                            ? Theme.of(context)
                                                .colorScheme
                                                .onPrimaryContainer
                                            : isMe
                                                ? Colors.white
                                                : null,
                                      ),
                                    ),
                                  ),
                                  if (isMe && !isFirstInGroup)
                                    const SizedBox(width: 15),
                                ],
                              ),
                              if (isLastInGroup)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 12, right: 12, top: 4),
                                  child: Text(
                                    _formatTime(message.createdAt),
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
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
                          color: Colors.black.withAlpha(30),
                          blurRadius: 4,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Column(
                        children: [
                          if (eventAsync.value?.createdBy?.id ==
                                  currentUserId &&
                              _isPinned)
                            Container(
                              padding: const EdgeInsets.all(8),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
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
                              if (eventAsync.value?.createdBy?.id ==
                                  currentUserId)
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
                                  onSubmitted: (_) => _sendMessage(
                                      eventAsync.value?.createdBy?.id ==
                                          currentUserId),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => _sendMessage(
                                    eventAsync.value?.createdBy?.id ==
                                        currentUserId),
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
                  bottom: eventAsync.value?.createdBy?.id == currentUserId &&
                          _isPinned
                      ? 140 // Account for pinned message banner
                      : 80,
                  child: FloatingActionButton.small(
                    onPressed: _scrollToBottom,
                    child: const Icon(Icons.keyboard_arrow_down),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
