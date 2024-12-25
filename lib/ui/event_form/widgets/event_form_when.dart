import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:squadquest/common.dart';

/// Date and time selection section for event form.
///
/// Displays a card with:
/// - Date picker
/// - Start time range (earliest and latest)
/// - Optional end time
class EventFormWhen extends ConsumerStatefulWidget {
  const EventFormWhen({
    super.key,
    required this.startDate,
    required this.onDateSelected,
    required this.startTimeMinProvider,
    required this.startTimeMaxProvider,
    required this.endTimeProvider,
    required this.isNewEvent,
    required this.instance,
  });

  final DateTime? startDate;
  final void Function(DateTime?) onDateSelected;
  final StateProvider<TimeOfDay?> startTimeMinProvider;
  final StateProvider<TimeOfDay?> startTimeMaxProvider;
  final StateProvider<TimeOfDay?> endTimeProvider;
  final bool isNewEvent;
  final dynamic instance;

  @override
  ConsumerState<EventFormWhen> createState() => _EventFormWhenState();
}

class _EventFormWhenState extends ConsumerState<EventFormWhen> {
  bool startTimeMaxSet = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'When',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                Icons.calendar_today,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Date'),
              subtitle: Text(
                widget.startDate != null
                    ? DateFormat('E, MMM d').format(widget.startDate!)
                    : 'Select a date',
                style: widget.startDate == null
                    ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)
                    : null,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Select',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
              onTap: () async {
                final newDate = await showDatePicker(
                  context: context,
                  initialDate: widget.startDate ?? DateTime.now(),
                  firstDate: widget.isNewEvent ||
                          widget.instance?.startTimeMax
                                  .isAfter(DateTime.now()) ==
                              true
                      ? DateTime.now()
                      : widget.instance!.startTimeMin,
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                widget.onDateSelected(newDate);
              },
            ),
            const Divider(),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      'Meet up between',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Consumer(
                          builder: (context, ref, _) {
                            final startTimeMin =
                                ref.watch(widget.startTimeMinProvider);
                            return InkWell(
                              onTap: () async {
                                final newTime = await showTimePicker(
                                  context: context,
                                  initialTime: startTimeMin ?? TimeOfDay.now(),
                                );
                                if (newTime != null) {
                                  ref
                                      .read(
                                          widget.startTimeMinProvider.notifier)
                                      .state = newTime;
                                  if (!startTimeMaxSet) {
                                    ref
                                            .read(widget
                                                .startTimeMaxProvider.notifier)
                                            .state =
                                        addMinutesToTimeOfDay(newTime, 15);
                                  }
                                }
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('Earliest'),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    startTimeMin != null
                                        ? MaterialLocalizations.of(context)
                                            .formatTimeOfDay(startTimeMin)
                                        : 'Select a time',
                                    style: startTimeMin == null
                                        ? Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant)
                                        : Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        Consumer(
                          builder: (context, ref, _) {
                            final startTimeMax =
                                ref.watch(widget.startTimeMaxProvider);
                            return InkWell(
                              onTap: () async {
                                final newTime = await showTimePicker(
                                  context: context,
                                  initialTime: startTimeMax ?? TimeOfDay.now(),
                                );
                                if (newTime != null) {
                                  ref
                                      .read(
                                          widget.startTimeMaxProvider.notifier)
                                      .state = newTime;
                                  setState(() {
                                    startTimeMaxSet = true;
                                  });
                                }
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('Latest'),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    startTimeMax != null
                                        ? startTimeMax.isBefore(ref.watch(widget
                                                    .startTimeMinProvider) ??
                                                TimeOfDay.now())
                                            ? '${DateFormat('E').format(widget.startDate?.add(const Duration(days: 1)) ?? DateTime.now())} ${MaterialLocalizations.of(context).formatTimeOfDay(startTimeMax)}'
                                            : MaterialLocalizations.of(context)
                                                .formatTimeOfDay(startTimeMax)
                                        : 'Select a time',
                                    style: startTimeMax == null
                                        ? Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant)
                                        : Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            Consumer(
              builder: (context, ref, _) {
                final endTime = ref.watch(widget.endTimeProvider);
                return ListTile(
                  leading: Icon(
                    Icons.access_time,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('End Time'),
                  subtitle: Text(
                    endTime != null
                        ? endTime.isBefore(
                                    ref.watch(widget.startTimeMinProvider) ??
                                        TimeOfDay.now()) ||
                                endTime.isBefore(
                                    ref.watch(widget.startTimeMaxProvider) ??
                                        TimeOfDay.now())
                            ? '${DateFormat('E').format(widget.startDate?.add(const Duration(days: 1)) ?? DateTime.now())} ${MaterialLocalizations.of(context).formatTimeOfDay(endTime)}'
                            : MaterialLocalizations.of(context)
                                .formatTimeOfDay(endTime)
                        : 'Optional',
                    style: endTime == null
                        ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant)
                        : null,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (endTime != null)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            ref.read(widget.endTimeProvider.notifier).state =
                                null;
                          },
                        ),
                      Text(
                        'Select',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                  onTap: () async {
                    final newTime = await showTimePicker(
                      context: context,
                      initialTime: endTime ?? TimeOfDay.now(),
                    );
                    if (newTime != null) {
                      ref.read(widget.endTimeProvider.notifier).state = newTime;
                    }
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
