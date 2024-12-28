import 'package:flutter/material.dart';
import 'package:squadquest/models/friend.dart';

class HomeFriendRequestsBanner extends StatelessWidget {
  final List<Friend> pendingRequests;
  final VoidCallback onTap;

  const HomeFriendRequestsBanner({
    super.key,
    required this.pendingRequests,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (pendingRequests.isEmpty) return const SizedBox.shrink();

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.tertiary.withAlpha(255),
              Theme.of(context).colorScheme.tertiaryContainer.withAlpha(255),
            ],
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(24),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_add,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'New Friend Requests',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatRequestText(pendingRequests),
                    style: const TextStyle(
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withAlpha(24),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('View'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRequestText(List<Friend> requests) {
    if (requests.isEmpty) return '';

    final names = requests.map((fr) => fr.requester!.displayName).toList();
    if (names.length == 1) {
      return '${names[0]} wants to be friends';
    } else if (names.length == 2) {
      return '${names[0]} and ${names[1]} want to be friends';
    } else {
      final othersCount = names.length - 1;
      return '${names[0]} and $othersCount others want to be friends';
    }
  }
}
