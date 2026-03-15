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
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => openThread(idea.id),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.tertiary.withAlpha(120),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: icon + activity type + chevron
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colorScheme.tertiary.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.lightbulb_outline,
                        size: 16,
                        color: colorScheme.tertiary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colorScheme.tertiary.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        idea.activityType,
                        style: TextStyle(
                          color: colorScheme.tertiary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (idea.proposedTimes.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.how_to_vote_outlined,
                                size: 11,
                                color: colorScheme.onTertiaryContainer),
                            const SizedBox(width: 3),
                            Text(
                              'Voting',
                              style: TextStyle(
                                color: colorScheme.onTertiaryContainer,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    Icon(Icons.chevron_right,
                        size: 18, color: colorScheme.onSurfaceVariant),
                  ],
                ),

                const SizedBox(height: 10),

                // Captain + audience
                buildAudienceRow(idea.captain, idea.audienceLabel, colorScheme),

                const SizedBox(height: 6),

                // Interest count + thread count
                Row(
                  children: [
                    if (idea.interestedCount > 0) ...[
                      Icon(Icons.favorite_border,
                          size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text(
                        '${idea.interestedCount} interested',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (idea.threadMessageCount > 0) ...[
                      Icon(Icons.chat_bubble_outline,
                          size: 13, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text(
                        '${idea.threadMessageCount} replies',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      formatTime(idea.timestamp),
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Response section
                buildResponseSection(
                    idea.id, hasResponse, isExpanded, showButtons, colorScheme),
              ],
            ),
          ),
        ),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => openThread(activity.id),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.primary.withAlpha(80),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: icon + activity type + confirmed badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.event_available,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        activity.activityType,
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              size: 11, color: colorScheme.onPrimaryContainer),
                          const SizedBox(width: 3),
                          Text(
                            'Confirmed',
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right,
                        size: 18, color: colorScheme.onSurfaceVariant),
                  ],
                ),

                const SizedBox(height: 10),

                // Confirmed time + location
                Row(
                  children: [
                    Icon(Icons.schedule,
                        size: 14, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      activity.confirmedTime,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.location_on_outlined,
                        size: 14, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        activity.confirmedLocation,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Captain + audience
                buildAudienceRow(
                    activity.captain, activity.audienceLabel, colorScheme),

                const SizedBox(height: 6),

                // Going count + thread count
                Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 14, color: colorScheme.primary),
                    const SizedBox(width: 3),
                    Text(
                      '${activity.goingCount} going',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (activity.threadMessageCount > 0) ...[
                      Icon(Icons.chat_bubble_outline,
                          size: 13, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text(
                        '${activity.threadMessageCount} replies',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      formatTime(activity.timestamp),
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Response section
                buildResponseSection(activity.id, hasResponse, isExpanded,
                    showButtons, colorScheme),
              ],
            ),
          ),
        ),
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
