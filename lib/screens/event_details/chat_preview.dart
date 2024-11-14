import 'package:flutter/material.dart';

import 'package:squadquest/models/event_message.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/components/tiles/profile.dart';
import 'package:squadquest/screens/chat.dart';

class EventDetailsChatPreview extends StatelessWidget {
  final EventMessage latestMessage;
  final InstanceID instanceId;

  const EventDetailsChatPreview({
    super.key,
    required this.latestMessage,
    required this.instanceId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(5),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(.25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => ChatScreen(
                  instanceId: instanceId, latestMessage: latestMessage),
            ),
          );
        },
        child: Column(
          children: [
            const Text('Latest message:'),
            Row(
              children: [
                Expanded(
                  child: Hero(
                    tag: 'message-${latestMessage.id}',
                    child: Material(
                      type: MaterialType.transparency,
                      child: ProfileTile(
                        profile: latestMessage.createdBy!,
                        subtitle: Text(latestMessage.content),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
