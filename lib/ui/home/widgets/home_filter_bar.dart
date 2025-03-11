import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';

import 'package:squadquest/models/instance.dart';
import 'package:squadquest/controllers/instances.dart';
import 'package:squadquest/controllers/rsvps.dart';

final _invitedEventsCountProvider = Provider<int>((ref) {
  final eventsAsync = ref.watch(instancesProvider);
  final now = DateTime.now();
  final rsvpsList = ref.watch(rsvpsProvider).valueOrNull ?? [];

  return eventsAsync.when(
    loading: () => 0,
    error: (_, __) => 0,
    data: (events) => events.where((event) {
      final rsvp =
          rsvpsList.firstWhereOrNull((rsvp) => rsvp.instanceId == event.id);
      return rsvp?.status == InstanceMemberStatus.invited &&
          event.getTimeGroup(now) != InstanceTimeGroup.past;
    }).length,
  );
});

class HomeFilterBar extends ConsumerWidget {
  final List<({String label, String description})> filters;
  final int selectedIndex;
  final ValueChanged<int> onFilterSelected;

  const HomeFilterBar({
    super.key,
    required this.filters,
    required this.selectedIndex,
    required this.onFilterSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitedCount = ref.watch(_invitedEventsCountProvider);

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filters.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = filters[index];
                final isSelected = selectedIndex == index;
                final isInvitedFilter = filter.label == 'Invited';

                return FilterChip(
                  selected: isSelected,
                  label: isInvitedFilter && invitedCount > 0
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(filter.label),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context)
                                        .colorScheme
                                        .onSecondaryContainer
                                        .withAlpha(40)
                                    : Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withAlpha(40),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                invitedCount.toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onSecondaryContainer
                                      : Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Text(filter.label),
                  onSelected: (selected) {
                    if (selected) {
                      onFilterSelected(index);
                    }
                  },
                  avatar: isSelected ? const Icon(Icons.check, size: 18) : null,
                  showCheckmark: false,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Text(
              filters[selectedIndex].description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurface.withAlpha(179),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
