import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storybook_toolkit/storybook_toolkit.dart';
import 'package:squadquest/app_scaffold.dart';

class EventDetailsScreen extends ConsumerWidget {
  const EventDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCancelled = context.knobs.boolean(
      label: 'Event is cancelled',
      initial: false,
      description: 'Show event in cancelled state',
    );

    final showBulletin = context.knobs.boolean(
      label: 'Show host bulletin',
      initial: false,
      description: 'Show the latest pinned message from host',
    );

    return AppScaffold(
      title: 'Board Game Night',
      titleStyle: isCancelled
          ? const TextStyle(decoration: TextDecoration.lineThrough)
          : null,
      body: CustomScrollView(
        slivers: [
          // Banner Image
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    'https://picsum.photos/800/400',
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Board Game Night',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            decoration:
                                isCancelled ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.people,
                                color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '8 going',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              children: [
                if (isCancelled)
                  Container(
                    color: Colors.red.withOpacity(0.1),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.cancel_outlined, color: Colors.red),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'This event has been cancelled',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Contact the host for more information',
                                style: TextStyle(
                                  color: Colors.red.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (showBulletin)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.push_pin,
                              size: 20,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Latest Update from Host',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'We\'ll be in the back room, look for the SquadQuest sign!',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '2 hours ago',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer
                                .withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildQuickAction(
                            context: context,
                            icon: Icons.check_circle_outline,
                            label: 'Going',
                            onTap: () {},
                          ),
                          _buildQuickAction(
                            context: context,
                            icon: Icons.map_outlined,
                            label: 'Map',
                            onTap: () {},
                          ),
                          _buildQuickAction(
                            context: context,
                            icon: Icons.share_outlined,
                            label: 'Share',
                            onTap: () {},
                          ),
                          _buildQuickAction(
                            context: context,
                            icon: Icons.chat_bubble_outline,
                            label: 'Chat',
                            onTap: () {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Event Details
                      _buildSection(
                        title: 'Details',
                        child: Column(
                          children: [
                            _buildDetailRow(
                              icon: Icons.calendar_today,
                              title: 'Saturday, Dec 2',
                              subtitle: '7:00 PM - 10:00 PM',
                            ),
                            const SizedBox(height: 16),
                            _buildDetailRow(
                              icon: Icons.location_on,
                              title: 'Game Knight Lounge',
                              subtitle: '3037 N Williams Ave',
                              trailing: const Icon(Icons.chevron_right),
                            ),
                            const SizedBox(height: 16),
                            _buildDetailRow(
                              icon: Icons.person,
                              title: 'Hosted by Sarah Chen',
                              subtitle: null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Description
                      _buildSection(
                        title: 'About',
                        child: const Text(
                          'Join us for a night of strategy and fun! We\'ll have a variety of games available, from quick party games to longer strategy games. Beginners welcome! Food and drinks available for purchase.',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Attendees
                      _buildSection(
                        title: 'Who\'s Coming',
                        trailing: TextButton(
                          onPressed: () {},
                          child: const Text('See All'),
                        ),
                        child: SizedBox(
                          height: 90,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: 6,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 16.0),
                                child: Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundColor: Colors.grey[300],
                                      child: Text('${index + 1}'),
                                    ),
                                    const SizedBox(height: 4),
                                    Text('Person ${index + 1}'),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () {},
                child: const Text('RSVP'),
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.more_vert),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }
}
