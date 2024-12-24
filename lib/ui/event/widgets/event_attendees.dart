import 'package:flutter/material.dart';

class EventAttendees extends StatelessWidget {
  const EventAttendees({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          _buildAttendeeSection(
            context,
            title: 'On My Way',
            attendees: const [
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
          const SizedBox(height: 16),
          _buildAttendeeSection(
            context,
            title: 'Going',
            attendees: const [
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
          const SizedBox(height: 16),
          _buildAttendeeSection(
            context,
            title: 'Maybe',
            attendees: const [
              _Attendee(
                name: 'Chris Brown',
                imageUrl: 'https://i.pravatar.cc/300?u=chris',
                subtitle: 'Friend',
                rsvpNote: 'Will confirm by Thursday',
              ),
            ],
            color: Theme.of(context).colorScheme.secondary,
          ),
        ]),
      ),
    );
  }

  Widget _buildAttendeeSection(
    BuildContext context, {
    required String title,
    required List<_Attendee> attendees,
    required Color color,
  }) {
    if (attendees.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
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
          ...attendees
              .map((attendee) => _buildAttendeeItem(context, attendee, color)),
        ],
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
