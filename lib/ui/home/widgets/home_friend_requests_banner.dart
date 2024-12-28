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

    final colorScheme = Theme.of(context).colorScheme;
    final bannerColor = colorScheme.primaryContainer;
    final textColor = colorScheme.onPrimaryContainer;
    final buttonColor = colorScheme.primary;
    final buttonTextColor = colorScheme.onPrimary;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bannerColor,
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outline.withAlpha(40),
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: buttonColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_add,
                color: buttonTextColor,
                size: 20,
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
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatRequestText(pendingRequests),
                    style: TextStyle(
                      color: textColor.withAlpha(230),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                foregroundColor: buttonTextColor,
                backgroundColor: buttonColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
