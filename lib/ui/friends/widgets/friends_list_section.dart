import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:squadquest/models/user.dart';
import 'package:squadquest/models/friend.dart';

class FriendsListSection extends StatelessWidget {
  final List<Friend> friends;
  final VoidCallback onAddFriend;
  final UserID currentUserId;

  const FriendsListSection({
    super.key,
    required this.friends,
    required this.onAddFriend,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Friends',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: onAddFriend,
                icon: const Icon(Icons.person_add),
                label: const Text('Add Friend'),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
              title: Text('${profile.firstName} ${profile.lastName}'),
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
