part of '../community_timeline.dart';

// ============================================================================
// Shared Widget Builders (extension on state class)
// ============================================================================

extension _SharedWidgets on _CommunityTimelineScreenState {
  // ==========================================================================
  // Audience Row
  // ==========================================================================

  Widget buildAudienceRow(
      _MockPerson captain, String audienceLabel, ColorScheme colorScheme) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: captain.color,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              captain.initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '${captain.name} shared with $audienceLabel',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // Response Section
  // ==========================================================================

  Widget buildResponseSection(
    String itemId,
    bool hasResponse,
    bool isExpanded,
    bool showButtons,
    ColorScheme colorScheme,
  ) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 200),
      crossFadeState:
          showButtons ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      firstChild: _buildResponseButtons(itemId, colorScheme),
      secondChild: hasResponse
          ? _buildCollapsedResponse(itemId, colorScheme)
          : const SizedBox.shrink(),
    );
  }

  Widget _buildResponseButtons(String itemId, ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: _buildResponseChip(
            itemId: itemId,
            label: "I'm in!",
            value: 'in',
            icon: Icons.rocket_launch_outlined,
            filled: true,
            colorScheme: colorScheme,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _buildResponseChip(
            itemId: itemId,
            label: 'Interested',
            value: 'interested',
            icon: Icons.star_outline,
            filled: false,
            colorScheme: colorScheme,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _buildResponseChip(
            itemId: itemId,
            label: 'Next Time',
            value: 'next_time',
            icon: Icons.schedule_outlined,
            filled: false,
            colorScheme: colorScheme,
          ),
        ),
      ],
    );
  }

  Widget _buildResponseChip({
    required String itemId,
    required String label,
    required String value,
    required IconData icon,
    required bool filled,
    required ColorScheme colorScheme,
  }) {
    return GestureDetector(
      onTap: () => setResponse(itemId, value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: filled ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: filled ? colorScheme.primary : colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color:
                  filled ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: filled
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsedResponse(String itemId, ColorScheme colorScheme) {
    final response = userResponses[itemId];
    if (response == null) return const SizedBox.shrink();

    final (String label, IconData icon) = switch (response) {
      'in' => ("I'm in!", Icons.rocket_launch),
      'interested' => ('Interested', Icons.star),
      'next_time' => ('Next Time', Icons.schedule),
      _ => ('', Icons.help),
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => toggleExpandResponse(itemId),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: colorScheme.onPrimaryContainer),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.edit,
                  size: 11,
                  color: colorScheme.onPrimaryContainer.withAlpha(150)),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // Photo Attachments
  // ==========================================================================

  Widget buildPhotoAttachments(List<String> photos, ColorScheme colorScheme) {
    if (photos.length == 1) {
      return Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image, size: 32, color: colorScheme.onSurfaceVariant),
              const SizedBox(height: 4),
              Text(
                'Photo',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Multiple photos: side by side
    return SizedBox(
      height: 120,
      child: Row(
        children: photos
            .map((photo) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(Icons.image,
                          size: 28, color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ==========================================================================
  // Mini Avatar Stack
  // ==========================================================================

  Widget buildMiniAvatarStack(
      List<_MockPerson> people, ColorScheme colorScheme) {
    final show = people.take(3).toList();
    return SizedBox(
      width: show.length * 12.0 + 6,
      height: 18,
      child: Stack(
        children: [
          for (int i = 0; i < show.length; i++)
            Positioned(
              left: i * 10.0,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: show[i].color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    show[i].initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================================================
  // Audience Indicator
  // ==========================================================================

  Widget buildAudienceIndicator(
    ColorScheme colorScheme, {
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 13, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Dashed Border Painter
// ============================================================================

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;
  final double borderRadius;

  _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashLength = 6,
    this.gapLength = 4,
    this.borderRadius = 16,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().first;
    final totalLength = metrics.length;

    double distance = 0;
    while (distance < totalLength) {
      final end = (distance + dashLength).clamp(0.0, totalLength);
      final dashPath = metrics.extractPath(distance, end);
      canvas.drawPath(dashPath, paint);
      distance += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      dashLength != oldDelegate.dashLength ||
      gapLength != oldDelegate.gapLength;
}
