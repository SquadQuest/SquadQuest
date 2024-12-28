import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadquest/models/friend.dart';

class HomeFriendRequestsBanner extends ConsumerWidget {
  final List<Friend> pendingRequests;
  final VoidCallback onTap;

  const HomeFriendRequestsBanner({
    super.key,
    required this.pendingRequests,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (pendingRequests.isEmpty) return const SizedBox.shrink();

    final requesters =
        pendingRequests.map((fr) => fr.requester!.displayName).join(', ');
    final isMultiple = pendingRequests.length > 1;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.tertiary,
              Theme.of(context).colorScheme.tertiaryContainer,
            ],
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onTertiary.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_add,
                color: Theme.of(context).colorScheme.onTertiary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New Friend Requests',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onTertiary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$requesters ${isMultiple ? 'want' : 'wants'} to be friends',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onTertiary
                          .withAlpha(204),
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onTertiary,
              ),
              child: const Text('View'),
            ),
          ],
        ),
      ),
    );
  }
}
