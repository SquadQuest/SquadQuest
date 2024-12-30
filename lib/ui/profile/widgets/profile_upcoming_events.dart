import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/ui/core/widgets/event_card.dart';

class ProfileUpcomingEvents extends StatelessWidget {
  final List<InstanceMember> rsvps;

  const ProfileUpcomingEvents({
    super.key,
    required this.rsvps,
  });

  @override
  Widget build(BuildContext context) {
    if (rsvps.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.event_busy,
                size: 48,
                color: Theme.of(context).colorScheme.primary.withAlpha(128),
              ),
              const SizedBox(height: 16),
              Text(
                'No upcoming events',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(179),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Events this person is attending will appear here',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(128),
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.event,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Upcoming Events',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        ...rsvps.map(
          (rsvp) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: EventCard(
              event: rsvp.instance!,
              rsvpStatus: rsvp.status,
              onTap: () {
                context.pushNamed(
                  'event-details',
                  pathParameters: {'id': rsvp.instance!.id!},
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
