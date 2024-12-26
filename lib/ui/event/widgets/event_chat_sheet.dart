import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/controllers/chat.dart';
import 'package:squadquest/controllers/instances.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/components/tiles/profile.dart';

import 'package:squadquest/ui/core/widgets/app_bottom_sheet.dart';

final DateFormat _dayTimeFormat = DateFormat('jm');
final DateFormat _weekTimeFormat = DateFormat('EEE, h:mm a');
final DateFormat _fullTimeFormat = DateFormat('MMM d, h:mm a');

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

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays > 7) {
      return _fullTimeFormat.format(time);
    }

    if (diff.inDays > 0) {
      return _weekTimeFormat.format(time);
    }

    return _dayTimeFormat.format(time);
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();

    if (content.isEmpty) {
      return;
    }

    final chatController = ref.read(chatProvider(widget.eventId).notifier);

    try {
      await chatController.post(content);
      _messageController.clear();
    } catch (error, stackTrace) {
      logger.e('Failed to send message', error: error, stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatProvider(widget.eventId));
    final eventAsync = ref.watch(eventDetailsProvider(widget.eventId));

    final messages = messagesAsync.value ?? [];

    return AppBottomSheet(
      height: widget.height,
      title: eventAsync.value != null
          ? 'Chat: ${eventAsync.value!.title}'
          : 'Chat',
      children: [
        // Messages
        if (messagesAsync.isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: RefreshProgressIndicator()),
          ),
        Expanded(
          child: ListView.builder(
            reverse: true,
            padding: EdgeInsets.zero,
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];

              return ProfileTile(
                profile: message.createdBy!,
                subtitle: Text(message.content),
                trailing: Text(_formatTime(message.createdAt)),
              );
            },
          ),
        ),

        // Input
        Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  autofocus: true,
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Type a message',
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
