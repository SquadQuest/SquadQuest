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

                          // Embedded community event (brought-along plan)
                          if (idea.eventRef != null) ...[
                            const SizedBox(height: 8),
                            buildEventRefChip(idea.eventRef!, colorScheme),
                          ],

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

                        // Embedded community event (brought-along plan)
                        if (activity.eventRef != null) ...[
                          const SizedBox(height: 8),
                          buildEventRefChip(activity.eventRef!, colorScheme),
                        ],
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
  // Community Event Card
  //
  // A born-confirmed recurring event broadcast by a community leader. Shows the
  // dual attendance model (anonymous headcount + opt-in public face-pile) and
  // the RSVP visibility gradient, plus the "Bring friends" bridge.
  // ==========================================================================

  Widget buildCommunityEventCard(
      _CommunityEventItem event, ColorScheme colorScheme) {
    final community = event.community;
    final going = goingEvents.contains(event.id);
    final isPublic = publicEvents.contains(event.id);

    // The displayed headcount reflects you joining (anonymously) on top of the
    // seeded total.
    final headcount = event.goingCount + (going ? 1 : 0);
    // The public face-pile gains your avatar only if you've gone public.
    final publicFaces = [
      if (isPublic) _you,
      ...event.publicGoing,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Community badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: community.color.withAlpha(40),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(community.icon, size: 18, color: community.color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author line: community + recurrence
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        community.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.repeat,
                        size: 12, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        event.recurrence,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Event card (solid, confirmed style)
                GestureDetector(
                  onTap: () => openThread(event.id),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: community.color.withAlpha(90),
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title + event badge
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                event.title,
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: community.color.withAlpha(30),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Event',
                                style: TextStyle(
                                  color: community.color,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right,
                                size: 16, color: colorScheme.onSurfaceVariant),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Time + location
                        Row(
                          children: [
                            Icon(Icons.schedule,
                                size: 12, color: colorScheme.onSurfaceVariant),
                            const SizedBox(width: 3),
                            Text(
                              event.time,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 12, color: colorScheme.onSurfaceVariant),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                event.location,
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),
                        Divider(height: 1, color: colorScheme.outlineVariant),
                        const SizedBox(height: 8),

                        // Dual attendance: anonymous headcount + public faces
                        _buildAttendanceRow(
                            headcount, publicFaces, colorScheme),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 6),
                // RSVP visibility gradient + bring friends
                _buildEventActions(event, going, isPublic, colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceRow(
      int headcount, List<_MockPerson> publicFaces, ColorScheme colorScheme) {
    return Row(
      children: [
        Icon(Icons.people, size: 14, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          '$headcount going',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 10),
        if (publicFaces.isNotEmpty) ...[
          buildMiniAvatarStack(publicFaces, colorScheme),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _publicFacesLabel(publicFaces),
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ] else
          Flexible(
            child: Text(
              'no one publicly yet',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  String _publicFacesLabel(List<_MockPerson> faces) {
    final names = faces.take(2).map((p) => p.name).join(', ');
    final extra = faces.length - 2;
    return extra > 0 ? '$names +$extra publicly' : '$names publicly';
  }

  Widget _buildEventActions(
    _CommunityEventItem event,
    bool going,
    bool isPublic,
    ColorScheme colorScheme,
  ) {
    return Row(
      children: [
        // Going toggle (tier 2: anonymous count)
        GestureDetector(
          onTap: () => toggleGoing(event.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: going ? colorScheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: going ? colorScheme.primary : colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  going ? Icons.check_circle : Icons.check_circle_outline,
                  size: 14,
                  color: going
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  going ? "I'm going" : 'Going?',
                  style: TextStyle(
                    color: going
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Public toggle (tier 3: visibility promotion) — only once going
        if (going)
          GestureDetector(
            onTap: () => togglePublic(event.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: isPublic
                    ? colorScheme.tertiaryContainer
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isPublic
                      ? colorScheme.tertiary
                      : colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPublic ? Icons.visibility : Icons.visibility_off_outlined,
                    size: 14,
                    color: isPublic
                        ? colorScheme.onTertiaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isPublic ? 'Public' : 'Show name',
                    style: TextStyle(
                      color: isPublic
                          ? colorScheme.onTertiaryContainer
                          : colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const Spacer(),
        // Bring friends bridge
        GestureDetector(
          onTap: () => bringFriendsToEvent(event),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.group_add_outlined,
                  size: 16, color: colorScheme.primary),
              const SizedBox(width: 4),
              Text(
                'Bring friends',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
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
