import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:squadquest/models/user.dart';

class ProfileMutualFriends extends StatelessWidget {
  final List<UserProfile> mutuals;

  const ProfileMutualFriends({
    super.key,
    required this.mutuals,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mutual Friends',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          ...mutuals.map((profile) => ListTile(
                leading: CircleAvatar(
                  foregroundImage: profile.photo != null
                      ? NetworkImage(profile.photo!.toString())
                      : null,
                  backgroundColor: Theme.of(context).colorScheme.inversePrimary,
                  child:
                      profile.photo == null ? Text(profile.firstName[0]) : null,
                ),
                title: Text(profile.displayName),
                onTap: () {
                  context.pushNamed('profile-view',
                      pathParameters: {'id': profile.id});
                },
              )),
        ],
      ),
    );
  }
}
