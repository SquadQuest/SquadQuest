import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadquest/app_scaffold.dart';

class EventDetailsV3Screen extends ConsumerWidget {
  const EventDetailsV3Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      title: 'Board Game Night',
      body: CustomScrollView(
        slivers: [
          // Banner Image with Overlay
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Friday, March 15 • 7:00 PM',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Game Knight Lounge',
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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Actions from v1
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

                  // About section from v1
                  _buildSection(
                    title: 'About',
                    child: const Text(
                      'Join us for a night of strategy and fun! We\'ll have a variety of games available, from quick party games to longer strategy games. Beginners welcome! Food and drinks available for purchase.',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Detailed attendee sections from v2
                  const Text(
                    'Attendees',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Attendee sections from v2
          _buildAttendeeSection(
            context,
            title: 'On My Way',
            attendees: [
              _Attendee(
                name: 'Mike Johnson',
                imageUrl: 'https://i.pravatar.cc/300?u=mike',
                subtitle: '5 minutes away',
              ),
              _Attendee(
                name: 'Emma Wilson',
                imageUrl: 'https://i.pravatar.cc/300?u=emma',
                subtitle: '2 minutes away',
                isCurrentUser: true,
                rsvpNote: 'Can\'t wait! I\'ll help set up the tables.',
              ),
            ],
            color: Theme.of(context).colorScheme.tertiary,
          ),

          _buildAttendeeSection(
            context,
            title: 'Going',
            attendees: [
              _Attendee(
                name: 'Sarah Chen',
                imageUrl: 'https://i.pravatar.cc/300?u=sarah',
                subtitle: 'Host',
                isHost: true,
              ),
              _Attendee(
                name: 'Alex Rivera',
                imageUrl: 'https://i.pravatar.cc/300?u=alex',
                subtitle: 'Friend',
                rsvpNote: 'Bringing snacks and drinks!',
              ),
            ],
            color: Theme.of(context).colorScheme.primary,
          ),

          _buildAttendeeSection(
            context,
            title: 'Maybe',
            attendees: [
              _Attendee(
                name: 'Chris Brown',
                imageUrl: 'https://i.pravatar.cc/300?u=chris',
                subtitle: 'Friend',
                rsvpNote: 'Will confirm by Thursday',
              ),
            ],
            color: Theme.of(context).colorScheme.secondary,
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
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

  Widget _buildAttendeeSection(
    BuildContext context, {
    required String title,
    required List<_Attendee> attendees,
    required Color color,
  }) {
    if (attendees.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverToBoxAdapter(
        child: Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          attendees.length.toString(),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              ...attendees.map(
                  (attendee) => _buildAttendeeItem(context, attendee, color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendeeItem(
      BuildContext context, _Attendee attendee, Color sectionColor) {
    return Container(
      decoration: BoxDecoration(
        color: attendee.isCurrentUser
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(attendee.imageUrl),
            ),
            title: Row(
              children: [
                Text(attendee.name),
                if (attendee.isCurrentUser) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'You',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                    ),
                  ),
                ],
                if (attendee.isHost) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: sectionColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Host',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.surface,
                          ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(attendee.subtitle),
          ),
          if (attendee.rsvpNote != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(72, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceVariant
                      .withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.format_quote,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        attendee.rsvpNote!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Attendee {
  final String name;
  final String imageUrl;
  final String subtitle;
  final bool isHost;
  final bool isCurrentUser;
  final String? rsvpNote;

  const _Attendee({
    required this.name,
    required this.imageUrl,
    required this.subtitle,
    this.isHost = false,
    this.isCurrentUser = false,
    this.rsvpNote,
  });
}
