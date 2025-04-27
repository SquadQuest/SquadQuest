import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:squadquest/models/user.dart';
import 'package:squadquest/models/friend.dart';

class FriendsListSection extends StatelessWidget {
  final List<Friend> friends;
  final VoidCallback? onAddFriend;
  final UserID currentUserId;
  final String? searchQuery;

  const FriendsListSection({
    super.key,
    required this.friends,
    this.onAddFriend,
    required this.currentUserId,
    this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (searchQuery == null) ...[
            Row(
              children: [
                Text(
                  'Friends',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                if (onAddFriend != null)
                  FilledButton.icon(
                    onPressed: onAddFriend,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add Friend'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (friends.isEmpty && searchQuery != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No friends found matching "$searchQuery"',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ...friends.map((friend) {
            final profile = friend.getOtherProfile(currentUserId)!;

            return ListTile(
              leading: Stack(
                children: [
                  CircleAvatar(
                    foregroundImage: profile.photo != null
                        ? NetworkImage(profile.photo!.toString())
                        : null,
                    backgroundColor:
                        Theme.of(context).colorScheme.inversePrimary,
                    child: profile.photo == null
                        ? Text(profile.firstName[0])
                        : null,
                  ),
                ],
              ),
              title: Text(profile.displayName),
              onTap: () {
                context.pushNamed('profile-view',
                    pathParameters: {'id': profile.id});
              },
            );
          }),
        ],
      ),
    );
  }
}
