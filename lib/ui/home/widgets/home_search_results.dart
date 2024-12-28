import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadquest/models/instance.dart';
import 'home_event_list.dart';

class HomeSearchResults extends ConsumerWidget {
  final String query;
  final List<Instance> events;
  final Function(Instance) onEventTap;
  final Function(Instance)? onEndEvent;
  final Map<InstanceID, InstanceMemberStatus>? rsvps;

  const HomeSearchResults({
    super.key,
    required this.query,
    required this.events,
    required this.onEventTap,
    this.onEndEvent,
    this.rsvps,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: Theme.of(context).colorScheme.primary.withAlpha(128),
            ),
            const SizedBox(height: 16),
            Text(
              'No events found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurface.withAlpha(179),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching for something else',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurface.withAlpha(128),
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Current search: "$query"',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurface.withAlpha(128),
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ),
      );
    }

    return HomeEventList(
      events: events,
      onEventTap: onEventTap,
      onEndEvent: onEndEvent,
      rsvps: rsvps,
      showSectionIcons: false,
    );
  }
}
