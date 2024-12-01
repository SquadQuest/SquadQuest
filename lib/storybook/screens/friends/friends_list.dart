import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storybook_toolkit/storybook_toolkit.dart';
import 'package:squadquest/app_scaffold.dart';

class FriendsListScreen extends ConsumerWidget {
  const FriendsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showEmptyState = context.knobs.boolean(
      label: 'Show empty state',
      initial: false,
      description: 'Toggle between empty and populated states',
    );

    return AppScaffold(
      title: 'Friends',
      body: showEmptyState
          ? _buildEmptyState(context)
          : CustomScrollView(
              slivers: [
                // Friend Requests Section
                SliverToBoxAdapter(
                  child: _buildRequestsSection(context),
                ),

                // Friends List Section
                SliverToBoxAdapter(
                  child: Padding(
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
                              onPressed: () {},
                              icon: const Icon(Icons.person_add),
                              label: const Text('Add Friend'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildFriendsList(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            const Text(
              'No Friends Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add friends to plan activities together and see what they\'re up to!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.person_add),
              label: const Text('Add Your First Friend'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsSection(BuildContext context) {
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
                    '2',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildRequestTile(
            context,
            name: 'John Smith',
            mutualFriends: 3,
            time: '2h ago',
          ),
          _buildRequestTile(
            context,
            name: 'Sarah Wilson',
            mutualFriends: 1,
            time: '5h ago',
          ),
        ],
      ),
    );
  }

  Widget _buildRequestTile(
    BuildContext context, {
    required String name,
    required int mutualFriends,
    required String time,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Text(name[0]),
      ),
      title: Text(name),
      subtitle: Text('$mutualFriends mutual friends • $time'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () {},
            child: const Text('Ignore'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () {},
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsList(BuildContext context) {
    return Column(
      children: [
        _buildFriendTile(
          context,
          name: 'Mike Johnson',
          status: 'Planning game night',
          isOnline: true,
        ),
        _buildFriendTile(
          context,
          name: 'Lisa Chen',
          status: 'Last seen 2h ago',
          isOnline: false,
        ),
        _buildFriendTile(
          context,
          name: 'David Kim',
          status: 'At Board Game Night',
          isOnline: true,
        ),
        _buildFriendTile(
          context,
          name: 'Emma Davis',
          status: 'Last seen yesterday',
          isOnline: false,
        ),
      ],
    );
  }

  Widget _buildFriendTile(
    BuildContext context, {
    required String name,
    required String status,
    required bool isOnline,
  }) {
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(name[0]),
          ),
          if (isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
        ],
      ),
      title: Text(name),
      subtitle: Text(
        status,
        style: TextStyle(
          color: isOnline
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () {},
      ),
    );
  }
}
