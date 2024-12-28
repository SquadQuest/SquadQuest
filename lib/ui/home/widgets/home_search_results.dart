import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadquest/models/instance.dart';
import 'home_event_list.dart';

class HomeSearchResults extends ConsumerWidget {
  final String query;
  final List<Instance> events;
  final Function(Instance) onEventTap;
  final Function(Instance)? onEndEvent;
  final Map<InstanceID, ({int going, int maybe, int omw, int invited})>?
      eventStats;

  const HomeSearchResults({
    super.key,
    required this.query,
    required this.events,
    required this.onEventTap,
    this.onEndEvent,
    this.eventStats,
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
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No events found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
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
      eventStats: eventStats,
      showSectionIcons: false,
    );
  }
}