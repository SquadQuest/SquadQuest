import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AttendeesModal extends ConsumerWidget {
  const AttendeesModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Who\'s Coming',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '24 people attending',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: SearchBar(
                hintText: 'Search attendees',
                leading: const Icon(Icons.search),
              ),
            ),

            // Tabs
            TabBar(
              tabs: const [
                Tab(text: 'Going (18)'),
                Tab(text: 'Maybe (6)'),
              ],
              labelColor: Theme.of(context).colorScheme.primary,
              indicatorColor: Theme.of(context).colorScheme.primary,
            ),

            // Attendee List
            Expanded(
              child: TabBarView(
                children: [
                  // Going Tab
                  ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _buildAttendeeItem(
                        context,
                        name: 'Sarah Chen',
                        subtitle: 'Host • Friend',
                        imageUrl: 'https://i.pravatar.cc/300?u=sarah',
                        isHost: true,
                      ),
                      _buildAttendeeItem(
                        context,
                        name: 'Mike Johnson',
                        subtitle: 'Friend',
                        imageUrl: 'https://i.pravatar.cc/300?u=mike',
                        showFriendButton: false,
                      ),
                      _buildAttendeeItem(
                        context,
                        name: 'Emma Wilson',
                        subtitle: 'Mutual friend with Sarah',
                        imageUrl: 'https://i.pravatar.cc/300?u=emma',
                      ),
                      _buildAttendeeItem(
                        context,
                        name: 'James Lee',
                        subtitle: 'Friend of friend',
                        imageUrl: 'https://i.pravatar.cc/300?u=james',
                      ),
                    ],
                  ),

                  // Maybe Tab
                  ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _buildAttendeeItem(
                        context,
                        name: 'Alex Rivera',
                        subtitle: 'Friend',
                        imageUrl: 'https://i.pravatar.cc/300?u=alex',
                        showFriendButton: false,
                      ),
                      _buildAttendeeItem(
                        context,
                        name: 'Taylor Swift',
                        subtitle: 'Mutual friend with Mike',
                        imageUrl: 'https://i.pravatar.cc/300?u=taylor',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendeeItem(
    BuildContext context, {
    required String name,
    required String subtitle,
    required String imageUrl,
    bool isHost = false,
    bool showFriendButton = true,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: NetworkImage(imageUrl),
      ),
      title: Row(
        children: [
          Text(name),
          if (isHost) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Host',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
      trailing: showFriendButton
          ? OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.person_add),
              label: const Text('Friend'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            )
          : null,
    );
  }
}
