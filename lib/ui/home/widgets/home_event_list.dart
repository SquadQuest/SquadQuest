import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadquest/models/instance.dart';
import 'home_event_card.dart';

class HomeEventList extends ConsumerWidget {
  final List<Instance> events;
  final Function(Instance) onEventTap;
  final Function(Instance)? onEndEvent;
  final Map<InstanceID, ({int going, int maybe, int omw, int invited})>?
      eventStats;
  final bool showSectionIcons;

  const HomeEventList({
    super.key,
    required this.events,
    required this.onEventTap,
    this.onEndEvent,
    this.eventStats,
    this.showSectionIcons = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No events found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    final now = DateTime.now();
    final sections = _groupEventsByTimeGroup(events, now);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        return _buildSection(
          context,
          title: _getSectionTitle(section.timeGroup),
          icon: _getSectionIcon(section.timeGroup),
          events: section.events,
        );
      },
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Instance> events,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showSectionIcons) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...events.map((event) {
            final stats = eventStats?[event.id!] ??
                (
                  going: 0,
                  maybe: 0,
                  omw: 0,
                  invited: 0,
                );

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: HomeEventCard(
                event: event,
                onTap: () => onEventTap(event),
                onEndTap: onEndEvent != null ? () => onEndEvent!(event) : null,
                goingCount: stats.going,
                maybeCount: stats.maybe,
                omwCount: stats.omw,
                invitedCount: stats.invited,
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  String _getSectionTitle(InstanceTimeGroup timeGroup) {
    switch (timeGroup) {
      case InstanceTimeGroup.current:
        return 'Happening Now';
      case InstanceTimeGroup.upcoming:
        return 'Coming Up';
      case InstanceTimeGroup.past:
        return 'Past Events';
    }
  }

  IconData _getSectionIcon(InstanceTimeGroup timeGroup) {
    switch (timeGroup) {
      case InstanceTimeGroup.current:
        return Icons.play_circle;
      case InstanceTimeGroup.upcoming:
        return Icons.upcoming;
      case InstanceTimeGroup.past:
        return Icons.history;
    }
  }
}

class _EventSection {
  final InstanceTimeGroup timeGroup;
  final List<Instance> events;

  _EventSection(this.timeGroup, this.events);
}

List<_EventSection> _groupEventsByTimeGroup(
    List<Instance> events, DateTime now) {
  final Map<InstanceTimeGroup, List<Instance>> groups = {};

  // Group events by time group
  for (final event in events) {
    final timeGroup = event.getTimeGroup(now);
    groups.putIfAbsent(timeGroup, () => []).add(event);
  }

  // Sort events within each group
  for (final events in groups.values) {
    events.sort((a, b) {
      // Sort past events in reverse chronological order
      if (a.startTimeMax.isBefore(now) && b.startTimeMax.isBefore(now)) {
        return b.startTimeMax.compareTo(a.startTimeMax);
      }
      // Sort current/upcoming events in chronological order
      return a.startTimeMax.compareTo(b.startTimeMax);
    });
  }

  // Create ordered sections
  final sections = <_EventSection>[];

  // Add current events first
  if (groups.containsKey(InstanceTimeGroup.current)) {
    sections.add(_EventSection(
      InstanceTimeGroup.current,
      groups[InstanceTimeGroup.current]!,
    ));
  }

  // Add upcoming events second
  if (groups.containsKey(InstanceTimeGroup.upcoming)) {
    sections.add(_EventSection(
      InstanceTimeGroup.upcoming,
      groups[InstanceTimeGroup.upcoming]!,
    ));
  }

  // Add past events last
  if (groups.containsKey(InstanceTimeGroup.past)) {
    sections.add(_EventSection(
      InstanceTimeGroup.past,
      groups[InstanceTimeGroup.past]!,
    ));
  }

  return sections;
}
