import 'package:flutter/material.dart';
import 'package:squadquest/models/instance.dart';

class HomeEventCard extends StatelessWidget {
  final Instance event;
  final VoidCallback onTap;
  final VoidCallback? onEndTap;
  final int goingCount;
  final int maybeCount;
  final int omwCount;
  final int invitedCount;

  const HomeEventCard({
    super.key,
    required this.event,
    required this.onTap,
    this.onEndTap,
    this.goingCount = 0,
    this.maybeCount = 0,
    this.omwCount = 0,
    this.invitedCount = 0,
  });

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
                        CircleAvatar(
                          radius: 12,
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          child: Text(
                            event.createdBy!.displayName[0],
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                        ),
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
                  const SizedBox(height: 16),

                  // Attendance Stats
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _buildAttendanceStats(context),
                  ),
                ],
              ),
            ),
          ],
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

    // TODO: Implement better time formatting
    return event.startTimeMin.toString();
  }

  Widget _buildAttendanceStats(BuildContext context) {
    final hasOmw =
        event.getTimeGroup(DateTime.now()) == InstanceTimeGroup.current;
    final stats = [
      if (hasOmw) (Icons.directions_run, omwCount, 'OMW'),
      (Icons.check_circle, goingCount, 'Going'),
      (Icons.schedule, maybeCount, 'Maybe'),
      (Icons.mail_outline, invitedCount, 'Invited'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '|',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSecondaryContainer
                        .withAlpha(128),
                  ),
                ),
              ),
            Icon(
              stats[i].$1,
              size: 16,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 4),
            Text(
              '${stats[i].$2} ${stats[i].$3}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
