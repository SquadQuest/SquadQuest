import 'package:flutter/material.dart';

import 'package:squadquest/common.dart';
import 'package:squadquest/models/friend.dart';

class FriendRequestsSection extends StatelessWidget {
  final List<Friend> requests;
  final Function(Friend, bool) onRespond;

  const FriendRequestsSection({
    super.key,
    required this.requests,
    required this.onRespond,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            title: Row(
              children: [
                Text(
                  'Friend Requests',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    requests.length.toString(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...requests.map((friend) {
            final requester = friend.requester!;
            return Dismissible(
              key: Key('friend-request-${friend.id}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                color: Theme.of(context).colorScheme.errorContainer,
                child: Text(
                  'Decline',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              confirmDismiss: (direction) {
                return showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                      'Are you sure you want to decline your friend request from ${requester.displayName}?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('No'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Yes'),
                      )
                    ],
                  ),
                );
              },
              onDismissed: (direction) {
                onRespond(friend, false);
              },
              child: ListTile(
                visualDensity: const VisualDensity(vertical: 0),
                leading: CircleAvatar(
                  foregroundImage: requester.photo == null
                      ? null
                      : NetworkImage(requester.photo.toString()),
                  backgroundColor: Theme.of(context).colorScheme.inversePrimary,
                  child: Text(requester.firstName[0]),
                ),
                title: Text(requester.displayName),
                subtitle: Text(
                  '${formatRelativeTime(friend.createdAt!)}\n${friend.mutualFriendCount} mutual friends',
                ),
                trailing: FilledButton(
                  onPressed: () => onRespond(friend, true),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text('Accept'),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
