import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/user.dart';

class HomeEventCard extends StatelessWidget {
  final Instance event;
  final VoidCallback onTap;
  final VoidCallback? onEndTap;

  const HomeEventCard({
    super.key,
    required this.event,
    required this.onTap,
    this.onEndTap,
  });

  Widget _buildHostAvatar(BuildContext context, UserProfile host) {
    if (host.photo != null) {
      return CircleAvatar(
        radius: 12,
        backgroundImage: NetworkImage(host.photo!.toString()),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      );
    }

    return CircleAvatar(
      radius: 12,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        host.displayName[0],
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  String _formatEventTime(Instance event, DateTime now) {
    if (event.getTimeGroup(now) == InstanceTimeGroup.current) {
      final startedAgo = now.difference(event.startTimeMin);
      if (startedAgo.inHours > 0) {
        return 'Started ${startedAgo.inHours}h ago';
      } else {
        return 'Started ${startedAgo.inMinutes}m ago';
      }
    }

    final startTime = event.startTimeMin;
    final endTime = event.startTimeMax;
    final dateFormat = DateFormat.MMMd(); // e.g., "Jan 15"
    final timeFormat = DateFormat.jm(); // e.g., "3:30 PM"

    // If event is in the past
    if (event.getTimeGroup(now) == InstanceTimeGroup.past) {
      return 'Ended ${_formatRelativeDate(endTime, now)}';
    }

    // If event is today
    if (startTime.year == now.year &&
        startTime.month == now.month &&
        startTime.day == now.day) {
      return 'Today at ${timeFormat.format(startTime)}';
    }

    // If event is tomorrow
    final tomorrow = now.add(const Duration(days: 1));
    if (startTime.year == tomorrow.year &&
        startTime.month == tomorrow.month &&
        startTime.day == tomorrow.day) {
      return 'Tomorrow at ${timeFormat.format(startTime)}';
    }

    // If event is within the next 6 days
    if (startTime.difference(now).inDays < 7) {
      return '${DateFormat.EEEE().format(startTime)} at ${timeFormat.format(startTime)}';
    }

    // If event is within this year
    if (startTime.year == now.year) {
      return '${dateFormat.format(startTime)} at ${timeFormat.format(startTime)}';
    }

    // If event is next year or later
    return '${DateFormat.yMMMd().format(startTime)} at ${timeFormat.format(startTime)}';
  }

  String _formatRelativeDate(DateTime date, DateTime now) {
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    }

    if (difference.inDays == 1) {
      return 'yesterday';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    }

    if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    }

    if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    }

    final years = (difference.inDays / 365).floor();
    return '$years ${years == 1 ? 'year' : 'years'} ago';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isLive = event.getTimeGroup(now) == InstanceTimeGroup.current;
    final isPast = event.getTimeGroup(now) == InstanceTimeGroup.past;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isLive)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Live Now',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title and Topic
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                decoration:
                                    isPast ? TextDecoration.lineThrough : null,
                              ),
                        ),
                      ),
                      if (event.topic != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondaryContainer
                                .withAlpha(128),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            event.topic!.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Host Info
                  if (event.createdBy != null)
                    Row(
                      children: [
                        _buildHostAvatar(context, event.createdBy!),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Hosted by ${event.createdBy!.displayName}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withAlpha(179),
                                    ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),

                  // Time and Location
                  DefaultTextStyle(
                    style: Theme.of(context).textTheme.bodySmall!,
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 16,
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                            ),
                            const SizedBox(width: 4),
                            Text(_formatEventTime(event, now)),
                          ],
                        ),
                        if (event.locationDescription.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.place,
                                size: 16,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  event.locationDescription,
                                  overflow: TextOverflow.ellipsis,
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
          ],
        ),
      ),
    );
  }
}
