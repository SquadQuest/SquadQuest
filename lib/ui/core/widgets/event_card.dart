import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/user.dart';

class EventCard extends StatelessWidget {
  final Instance event;
  final VoidCallback onTap;
  final VoidCallback? onEndTap;
  final InstanceMemberStatus? rsvpStatus;

  const EventCard({
    super.key,
    required this.event,
    required this.onTap,
    this.onEndTap,
    this.rsvpStatus,
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

  Widget _buildRsvpStatus(BuildContext context) {
    if (rsvpStatus == null) return const SizedBox.shrink();

    final (backgroundColor, textColor, text) = switch (rsvpStatus!) {
      InstanceMemberStatus.invited => (
          Theme.of(context).colorScheme.tertiaryContainer,
          Theme.of(context).colorScheme.onTertiaryContainer,
          'Invited'
        ),
      InstanceMemberStatus.maybe => (
          Colors.orange[100]!,
          Colors.orange[900]!,
          'Maybe'
        ),
      InstanceMemberStatus.yes => (
          Theme.of(context).colorScheme.primaryContainer,
          Theme.of(context).colorScheme.onPrimaryContainer,
          'Going'
        ),
      InstanceMemberStatus.omw => (
          Theme.of(context).colorScheme.inversePrimary,
          Theme.of(context).colorScheme.primary,
          'On my way'
        ),
      InstanceMemberStatus.no => (
          Theme.of(context).colorScheme.surfaceVariant,
          Theme.of(context).colorScheme.onSurfaceVariant,
          'Not going'
        ),
      _ => (null, null, null),
    };

    if (text == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: rsvpStatus == InstanceMemberStatus.omw
            ? Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 1,
              )
            : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: textColor,
          fontWeight: FontWeight.w500,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Opacity(
      opacity: isPast ? 0.5 : 1.0,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              // Banner Photo Background
              if (event.bannerPhoto != null) ...[
                Positioned.fill(
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      isDark
                          ? Colors.black.withAlpha(130)
                          : Colors.white.withAlpha(180),
                      isDark ? BlendMode.darken : BlendMode.lighten,
                    ),
                    child: Image.network(
                      event.bannerPhoto!.toString(),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Theme.of(context).cardColor,
                        ],
                        stops: const [0.0, 0.8],
                      ),
                    ),
                  ),
                ),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isLive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
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
                                style: Theme.of(context).textTheme.titleMedium,
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

                        // Host Info and RSVP Status
                        Row(
                          children: [
                            if (event.createdBy != null) ...[
                              _buildHostAvatar(context, event.createdBy!),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Posted by ${event.createdBy!.displayName}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withAlpha(179),
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            if (rsvpStatus != null) ...[
                              const SizedBox(width: 8),
                              _buildRsvpStatus(context),
                            ],
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
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color,
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

                        // End Event Button
                        if (onEndTap != null && isLive) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: onEndTap,
                            icon: const Icon(Icons.stop_circle_outlined),
                            label: const Text('End Event'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
