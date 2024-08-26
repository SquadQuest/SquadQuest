import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/controllers/chat.dart';
import 'package:squadquest/controllers/instances.dart';
import 'package:squadquest/models/event_message.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/components/tiles/profile.dart';

final DateFormat _dayTimeFormat = DateFormat('jm');
final DateFormat _weekTimeFormat = DateFormat('EEE, h:mm a');
final DateFormat _fullTimeFormat = DateFormat('MMM d, h:mm a');

class ChatScreen extends ConsumerStatefulWidget {
  final InstanceID instanceId;
  final EventMessage? latestMessage;
  final bool autofocus;

  const ChatScreen(
      {super.key,
      required this.instanceId,
      this.latestMessage,
      this.autofocus = false});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
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

    final chatController = ref.read(chatProvider(widget.instanceId).notifier);

    try {
      await chatController.post(content);

      _messageController.clear();
    } catch (error, stackTrace) {
      logger.e('Failed to send message', error: error, stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatProvider(widget.instanceId));
    final eventAsync = ref.watch(eventDetailsProvider(widget.instanceId));

    return AppScaffold(
      title: eventAsync.value != null
          ? 'Chat: ${eventAsync.value!.title}'
          : 'Chat',
      body: SafeArea(
        child: Column(
          children: [
            if (messagesAsync.isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: RefreshProgressIndicator(),
              ),
            Expanded(
              child: ListView.builder(
                reverse: true,
                itemCount: messagesAsync.maybeWhen(
                  data: (messages) => messages.length,
                  orElse: () => widget.latestMessage != null ? 1 : 0,
                ),
                itemBuilder: (context, index) {
                  final messages = messagesAsync.maybeWhen(
                    data: (messages) => messages,
                    orElse: () => [widget.latestMessage!],
                  );

                  final message = messages[index];

                  final tile = ProfileTile(
                    profile: message.createdBy!,
                    subtitle: Text(message.content),
                    trailing: Text(_formatTime(message.createdAt)),
                  );

                  if (index > 0) {
                    return tile;
                  }

                  return Hero(
                    tag: 'message-${message.id}',
                    child: Material(
                      type: MaterialType.transparency,
                      child: tile,
                    ),
                  );
                },
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    autofocus: widget.autofocus,
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
