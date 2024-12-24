import 'package:flutter/material.dart';

import 'package:squadquest/models/instance.dart';

class EventQuickActions extends StatelessWidget {
  final InstanceMemberStatus? selectedStatus;
  final VoidCallback onRsvpTap;

  const EventQuickActions({
    super.key,
    required this.selectedStatus,
    required this.onRsvpTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          context,
          onTap: onRsvpTap,
          selected: selectedStatus != null,
          icon: _getRsvpIcon(),
          label: selectedStatus?.name.toUpperCase() ?? 'RSVP',
        ),
        _buildActionButton(
          context,
          onTap: () {},
          icon: Icons.map_outlined,
          label: 'Map',
        ),
        _buildActionButton(
          context,
          onTap: () {},
          icon: Icons.share_outlined,
          label: 'Share',
        ),
        _buildActionButton(
          context,
          onTap: () {},
          icon: Icons.chat_bubble_outline,
          label: 'Chat',
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 24,
                color: selected ? Theme.of(context).colorScheme.primary : null,
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
      ),
    );
  }
}
