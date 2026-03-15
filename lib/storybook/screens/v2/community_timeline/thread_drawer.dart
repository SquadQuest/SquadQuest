part of '../community_timeline.dart';

// ============================================================================
// Thread Drawer Builders (extension on state class)
// ============================================================================

extension _ThreadDrawer on _CommunityTimelineScreenState {
  // ==========================================================================
  // Thread Drawer Container
  // ==========================================================================

  Widget buildThreadDrawer(ColorScheme colorScheme) {
    final isOpen = activeThreadItemId != null;
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth * 0.85;

    // Find the active item
    _TimelineItem? activeItem;
    if (isOpen) {
      final allItems = [...communityItems, ...squadItems];
      activeItem =
          allItems.where((item) => item.id == activeThreadItemId).firstOrNull;
    }

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      top: 0,
      bottom: 0,
      right: isOpen ? 0 : -drawerWidth,
      width: drawerWidth,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 16,
              offset: const Offset(-4, 0),
            ),
          ],
        ),
        child: activeItem == null
            ? const SizedBox.shrink()
            : Column(
                children: [
                  _buildThreadHeader(activeItem, colorScheme),
                  Expanded(
                    child: _buildThreadContent(activeItem, colorScheme),
                  ),
                  _buildThreadInput(colorScheme),
                ],
              ),
      ),
    );
  }

  // ==========================================================================
  // Thread Header
  // ==========================================================================

  Widget _buildThreadHeader(_TimelineItem item, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.only(
        top: 12,
        left: 16,
        right: 8,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Type label + close button
          Row(
            children: [
              Expanded(
                child: switch (item) {
                  _IdeaItem() => Row(
                      children: [
                        Icon(Icons.lightbulb_outline,
                            size: 18, color: colorScheme.tertiary),
                        const SizedBox(width: 6),
                        Text(
                          'Idea',
                          style: TextStyle(
                            color: colorScheme.tertiary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  _ActivityItem() => Row(
                      children: [
                        Icon(Icons.event_available,
                            size: 18, color: colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Activity',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  _SquadTextMessage() => Row(
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 16, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(
                          'Thread',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                },
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: closeThread,
                iconSize: 20,
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Item-specific header content
          switch (item) {
            _IdeaItem() => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.activityType,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  buildAudienceRow(
                      item.captain, item.audienceLabel, colorScheme),
                ],
              ),
            _ActivityItem() => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.activityType,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.schedule,
                          size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(item.confirmedTime,
                          style: TextStyle(
                              color: colorScheme.onSurface, fontSize: 13)),
                      const SizedBox(width: 10),
                      Icon(Icons.location_on_outlined,
                          size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(item.confirmedLocation,
                            style: TextStyle(
                                color: colorScheme.onSurface, fontSize: 13),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  buildAudienceRow(
                      item.captain, item.audienceLabel, colorScheme),
                ],
              ),
            _SquadTextMessage() => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: item.sender.color,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            item.sender.initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.sender.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  if (item.content != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        item.content!,
                        style: TextStyle(
                            color: colorScheme.onSurface, fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
          },

          // Response section in thread header (for ideas/activities)
          if (item is _IdeaItem || item is _ActivityItem) ...[
            const SizedBox(height: 10),
            buildResponseSection(
              item.id,
              userResponses.containsKey(item.id),
              expandedResponses.contains(item.id),
              !userResponses.containsKey(item.id) ||
                  expandedResponses.contains(item.id),
              colorScheme,
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================================================
  // Thread Content
  // ==========================================================================

  Widget _buildThreadContent(_TimelineItem item, ColorScheme colorScheme) {
    // Get thread messages based on item
    final messages = item.id == 'idea_paddleboard'
        ? paddleboardThreadMessages
        : genericThreadMessages;

    final showVoting = item is _IdeaItem && item.proposedTimes.isNotEmpty;

    return ListView(
      controller: threadScrollController,
      padding: const EdgeInsets.all(12),
      children: [
        // Voting section (for ideas with proposed times/locations)
        if (showVoting) ...[
          _buildVotingSection(
            'When?',
            item.id == 'idea_paddleboard' ? paddleboardTimeVotes : [],
            userTimeVotes,
            toggleTimeVote,
            item.allowSuggestions,
            colorScheme,
          ),
          const SizedBox(height: 12),
          _buildVotingSection(
            'Where?',
            item.id == 'idea_paddleboard' ? paddleboardLocationVotes : [],
            userLocationVotes,
            toggleLocationVote,
            item.allowSuggestions,
            colorScheme,
          ),
          const SizedBox(height: 12),
          Divider(color: colorScheme.outlineVariant),
          const SizedBox(height: 8),
        ],

        // Thread messages
        ...messages.map((msg) => _buildThreadMessage(msg, colorScheme)),
      ],
    );
  }

  // ==========================================================================
  // Voting Section
  // ==========================================================================

  Widget _buildVotingSection(
    String title,
    List<_VoteOption> options,
    Set<String> votes,
    void Function(String) onToggleVote,
    bool allowSuggestions,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (allowSuggestions)
              GestureDetector(
                onTap: () {},
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 14, color: colorScheme.primary),
                    const SizedBox(width: 2),
                    Text(
                      'Suggest',
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
        const SizedBox(height: 8),
        ...options.map((option) {
          final voted = votes.contains(option.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GestureDetector(
              onTap: () => onToggleVote(option.id),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: voted
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: voted
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        option.label,
                        style: TextStyle(
                          color: voted
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface,
                          fontWeight:
                              voted ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (option.voters.isNotEmpty) ...[
                      buildMiniAvatarStack(option.voters, colorScheme),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      '${option.voters.length}',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (voted) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.check, size: 14, color: colorScheme.primary),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ==========================================================================
  // Thread Messages
  // ==========================================================================

  Widget _buildThreadMessage(_ThreadMessage message, ColorScheme colorScheme) {
    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.content ?? '',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: message.sender!.color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                message.sender!.initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      message.sender!.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      formatTime(message.timestamp),
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                if (message.content != null)
                  Text(
                    message.content!,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 13,
                    ),
                  ),
                if (message.photos != null && message.photos!.isNotEmpty)
                  Padding(
                    padding:
                        EdgeInsets.only(top: message.content != null ? 6 : 2),
                    child: buildPhotoAttachments(message.photos!, colorScheme),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // Thread Input
  // ==========================================================================

  Widget _buildThreadInput(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.photo_outlined),
              onPressed: () {},
              iconSize: 20,
              color: colorScheme.onSurfaceVariant,
            ),
            Expanded(
              child: TextField(
                controller: threadMessageController,
                decoration: InputDecoration(
                  hintText: 'Reply...',
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
                minLines: 1,
                maxLines: 4,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.send),
              iconSize: 20,
              color: colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
