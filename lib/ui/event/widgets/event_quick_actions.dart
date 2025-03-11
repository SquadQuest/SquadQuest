import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/models/instance.dart';
import 'package:squadquest/controllers/chat.dart' show chatMessageCountProvider;
import 'package:squadquest/controllers/instances.dart' show eventPointsProvider;

import 'event_rsvp_inline_toolbar.dart';

class EventQuickActions extends ConsumerWidget {
  final InstanceMemberStatus? selectedStatus;
  final InstanceID eventId;
  final VoidCallback onRsvpTap;
  final Function(InstanceMemberStatus status, String? note)?
      onRsvpStatusSelected;
  final VoidCallback onMapTap;
  final VoidCallback onShareTap;
  final VoidCallback onChatTap;
  final bool showChat;

  const EventQuickActions({
    super.key,
    required this.selectedStatus,
    required this.eventId,
    required this.onRsvpTap,
    required this.onMapTap,
    required this.onShareTap,
    required this.onChatTap,
    this.showChat = true,
    this.onRsvpStatusSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventPointsAsync = ref.watch(eventPointsProvider(eventId));
    final messageCountAsync = ref.watch(chatMessageCountProvider(eventId));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              context,
              onTap: onRsvpTap,
              selected: selectedStatus != null &&
                  selectedStatus != InstanceMemberStatus.invited,
              icon: _getRsvpIcon(),
              label: selectedStatus?.name.toUpperCase() ?? 'RSVP',
            ),
            _buildActionButton(
              context,
              onTap: onMapTap,
              icon: Icons.map_outlined,
              label: 'Map',
              badge: eventPointsAsync.whenOrNull(
                data: (eventPoints) =>
                    eventPoints!.users > 0 ? eventPoints.users : null,
              ),
            ),
            if (showChat)
              _buildActionButton(
                context,
                onTap: onChatTap,
                icon: Icons.chat_bubble_outline,
                label: 'Chat',
                badge: messageCountAsync.whenOrNull(
                  data: (count) => (count ?? 0) > 0 ? count : null,
                ),
              ),
            _buildActionButton(
              context,
              onTap: onShareTap,
              icon: Icons.share_outlined,
              label: 'Share',
            ),
          ],
        ),

        // Show inline RSVP toolbar when status is null or invited
        if (selectedStatus == InstanceMemberStatus.invited)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: EventRsvpInlineToolbar(
              onStatusSelected: (status, note) {
                if (onRsvpStatusSelected != null) {
                  onRsvpStatusSelected!(status, note);
                } else {
                  onRsvpTap();
                }
              },
            ),
          ),
      ],
    );
  }

  IconData _getRsvpIcon() {
    if (selectedStatus == null) return Icons.check_circle_outline;
    switch (selectedStatus!) {
      case InstanceMemberStatus.omw:
        return Icons.directions_run;
      case InstanceMemberStatus.yes:
        return Icons.check_circle;
      case InstanceMemberStatus.maybe:
        return Icons.help;
      case InstanceMemberStatus.no:
        return Icons.cancel;
      case InstanceMemberStatus.invited:
        return Icons.mail_outline;
    }
  }

  Widget _buildActionButton(
    BuildContext context, {
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    bool selected = false,
    int? badge,
  }) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 64,
          height: 64,
          decoration: selected
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                )
              : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 24,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Positioned(
                  right: 12,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 14,
                    ),
                    child: Text(
                      badge.toString(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.surface,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
