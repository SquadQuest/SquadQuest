part of '../community_timeline.dart';

// ============================================================================
// Timeline Card Builders (extension on state class)
// ============================================================================

extension _TimelineCards on _CommunityTimelineScreenState {
  // ==========================================================================
  // Idea Card
  // ==========================================================================

  Widget buildIdeaCard(_IdeaItem idea, ColorScheme colorScheme) {
    final hasResponse = userResponses.containsKey(idea.id);
    final isExpanded = expandedResponses.contains(idea.id);
    final showButtons = !hasResponse || isExpanded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Captain avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: idea.captain.color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                idea.captain.initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Content column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author line
                Row(
                  children: [
                    Text(
                      idea.captain.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      ' shared with ',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        idea.audienceLabel,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formatTime(idea.timestamp),
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Compact idea tile
                GestureDetector(
                  onTap: () => openThread(idea.id),
                  child: CustomPaint(
                    painter: _DashedBorderPainter(
                      color: colorScheme.tertiary.withAlpha(150),
                      strokeWidth: 1.5,
                      dashLength: 6,
                      gapLength: 4,
                      borderRadius: 12,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Type + activity + voting badge
                          Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                size: 15,
                                color: colorScheme.tertiary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                idea.activityType,
                                style: TextStyle(
                                  color: colorScheme.tertiary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (idea.proposedTimes.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: colorScheme.tertiaryContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.how_to_vote_outlined,
                                          size: 10,
                                          color:
                                              colorScheme.onTertiaryContainer),
                                      const SizedBox(width: 2),
                                      Text(
                                        'Voting',
                                        style: TextStyle(
                                          color:
                                              colorScheme.onTertiaryContainer,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const Spacer(),
                              Icon(Icons.chevron_right,
                                  size: 16,
                                  color: colorScheme.onSurfaceVariant),
                            ],
                          ),

                          // Stats row
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (idea.interestedCount > 0) ...[
                                Icon(Icons.favorite_border,
                                    size: 12,
                                    color: colorScheme.onSurfaceVariant),
                                const SizedBox(width: 2),
                                Text(
                                  '${idea.interestedCount}',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (idea.threadMessageCount > 0) ...[
                                Icon(Icons.chat_bubble_outline,
                                    size: 11,
                                    color: colorScheme.onSurfaceVariant),
                                const SizedBox(width: 2),
                                Text(
                                  '${idea.threadMessageCount}',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Response section (below the tile)
                const SizedBox(height: 6),
                buildResponseSection(
                    idea.id, hasResponse, isExpanded, showButtons, colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // Activity Card
  // ==========================================================================

  Widget buildActivityCard(_ActivityItem activity, ColorScheme colorScheme) {
    final hasResponse = userResponses.containsKey(activity.id);
    final isExpanded = expandedResponses.contains(activity.id);
    final showButtons = !hasResponse || isExpanded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Captain avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: activity.captain.color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                activity.captain.initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Content column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author line
                Row(
                  children: [
                    Text(
                      activity.captain.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      ' shared with ',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        activity.audienceLabel,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formatTime(activity.timestamp),
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Compact activity tile
                GestureDetector(
                  onTap: () => openThread(activity.id),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.primary.withAlpha(80),
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Type + activity + confirmed badge
                        Row(
                          children: [
                            Icon(
                              Icons.event_available,
                              size: 15,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              activity.activityType,
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle,
                                      size: 10,
                                      color: colorScheme.onPrimaryContainer),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Confirmed',
                                    style: TextStyle(
                                      color: colorScheme.onPrimaryContainer,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Icon(Icons.chevron_right,
                                size: 16, color: colorScheme.onSurfaceVariant),
                          ],
                        ),

                        // Time + location
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.schedule,
                                size: 12, color: colorScheme.onSurfaceVariant),
                            const SizedBox(width: 3),
                            Text(
                              activity.confirmedTime,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.location_on_outlined,
                                size: 12, color: colorScheme.onSurfaceVariant),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                activity.confirmedLocation,
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (activity.goingCount > 0) ...[
                              Icon(Icons.check_circle_outline,
                                  size: 12, color: colorScheme.primary),
                              const SizedBox(width: 2),
                              Text(
                                '${activity.goingCount}',
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                            if (activity.threadMessageCount > 0) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.chat_bubble_outline,
                                  size: 11,
                                  color: colorScheme.onSurfaceVariant),
                              const SizedBox(width: 2),
                              Text(
                                '${activity.threadMessageCount}',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Response section (below the tile)
                const SizedBox(height: 6),
                buildResponseSection(activity.id, hasResponse, isExpanded,
                    showButtons, colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // Squad Text Message
  // ==========================================================================

  Widget buildSquadMessage(_SquadTextMessage message, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => openThread(message.id),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: message.sender.color,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  message.sender.initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + time
                  Row(
                    children: [
                      Text(
                        message.sender.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatTime(message.timestamp),
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Text content
                  if (message.content != null)
                    Text(
                      message.content!,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 14,
                      ),
                    ),
                  // Photo attachments
                  if (message.photos != null && message.photos!.isNotEmpty)
                    Padding(
                      padding:
                          EdgeInsets.only(top: message.content != null ? 6 : 0),
                      child:
                          buildPhotoAttachments(message.photos!, colorScheme),
                    ),
                  // Thread indicator
                  if (message.threadMessageCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.subdirectory_arrow_right,
                              size: 14, color: colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            '${message.threadMessageCount} ${message.threadMessageCount == 1 ? 'reply' : 'replies'}',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
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
