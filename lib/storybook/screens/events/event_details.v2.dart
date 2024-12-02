import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadquest/app_scaffold.dart';

class EventDetailsV2Screen extends ConsumerWidget {
  const EventDetailsV2Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      title: 'Board Game Night',
      body: CustomScrollView(
        slivers: [
          // Event Banner
          SliverToBoxAdapter(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                'https://picsum.photos/800/400',
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Event Info
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Board Game Night',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Friday, March 15 • 7:00 PM',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Sarah\'s Place',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // RSVP Stats
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildRsvpStat(
                        context,
                        count: 18,
                        label: 'Going',
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      _buildRsvpStat(
                        context,
                        count: 3,
                        label: 'On My Way',
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                      _buildRsvpStat(
                        context,
                        count: 6,
                        label: 'Maybe',
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      _buildRsvpStat(
                        context,
                        count: 2,
                        label: 'No',
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Attendees Section
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                'Attendees',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // On My Way
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
              _Attendee(
                name: 'James Lee',
                imageUrl: 'https://i.pravatar.cc/300?u=james',
                subtitle: '10 minutes away',
              ),
            ],
            color: Theme.of(context).colorScheme.tertiary,
          ),

          // Going
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
              _Attendee(
                name: 'Taylor Swift',
                imageUrl: 'https://i.pravatar.cc/300?u=taylor',
                subtitle: 'Friend of Sarah',
              ),
            ],
            color: Theme.of(context).colorScheme.primary,
          ),

          // Maybe
          _buildAttendeeSection(
            context,
            title: 'Maybe',
            attendees: [
              _Attendee(
                name: 'Chris Brown',
                imageUrl: 'https://i.pravatar.cc/300?u=chris',
                subtitle: 'Friend',
                rsvpNote: 'Will confirm by Thursday - waiting on work schedule',
              ),
              _Attendee(
                name: 'Diana Prince',
                imageUrl: 'https://i.pravatar.cc/300?u=diana',
                subtitle: 'Friend of Alex',
              ),
            ],
            color: Theme.of(context).colorScheme.secondary,
          ),

          // Not Going
          _buildAttendeeSection(
            context,
            title: 'Not Going',
            attendees: [
              _Attendee(
                name: 'Bruce Wayne',
                imageUrl: 'https://i.pravatar.cc/300?u=bruce',
                subtitle: 'Friend',
                rsvpNote: 'Out of town for business',
              ),
            ],
            color: Theme.of(context).colorScheme.error,
          ),

          // Invited
          _buildAttendeeSection(
            context,
            title: 'Invited',
            attendees: [
              _Attendee(
                name: 'Peter Parker',
                imageUrl: 'https://i.pravatar.cc/300?u=peter',
                subtitle: 'Invited by Sarah',
              ),
              _Attendee(
                name: 'Mary Jane',
                imageUrl: 'https://i.pravatar.cc/300?u=mary',
                subtitle: 'Invited by Alex',
              ),
            ],
            color: Theme.of(context).colorScheme.outline,
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  Widget _buildRsvpStat(
    BuildContext context, {
    required int count,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              count.toString(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildAttendeeSection(
    BuildContext context, {
    required String title,
    required List<_Attendee> attendees,
    required Color color,
  }) {
    if (attendees.isEmpty)
      return const SliverToBoxAdapter(child: SizedBox.shrink());

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
