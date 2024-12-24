import 'package:flutter/material.dart';

import 'package:squadquest/models/instance.dart';

class EventRsvpSheet extends StatefulWidget {
  final Instance event;
  final InstanceMemberStatus? selectedStatus;
  // final String note;
  final Function(InstanceMemberStatus status, String note) onStatusSelected;
  final VoidCallback onRemoveRsvp;

  const EventRsvpSheet({
    super.key,
    required this.event,
    this.selectedStatus,
    // required this.note,
    required this.onStatusSelected,
    required this.onRemoveRsvp,
  });

  @override
  State<EventRsvpSheet> createState() => _EventRsvpSheetState();
}

class _EventRsvpSheetState extends State<EventRsvpSheet> {
  // late final TextEditingController _noteController;
  late InstanceMemberStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    // _noteController = TextEditingController(text: widget.note);
    _selectedStatus = widget.selectedStatus;
  }

  @override
  void dispose() {
    // _noteController.dispose();
    super.dispose();
  }

  Widget _buildRsvpOption({
    required InstanceMemberStatus status,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedStatus == status;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
          fontWeight: isSelected ? FontWeight.bold : null,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: isSelected ? const Icon(Icons.check) : null,
      onTap: () {
        widget.onStatusSelected(status, ''); // _noteController.text
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'RSVP to ${widget.event.title}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildRsvpOption(
                status: InstanceMemberStatus.omw,
                icon: Icons.directions_run,
                title: "I'm on my way!",
                subtitle: "Let others know you're heading there",
              ),
              _buildRsvpOption(
                status: InstanceMemberStatus.yes,
                icon: Icons.check_circle,
                title: "I'm going",
                subtitle: "You'll get updates about this event",
              ),
              _buildRsvpOption(
                status: InstanceMemberStatus.maybe,
                icon: Icons.help,
                title: "Maybe",
                subtitle: "You'll still get updates about this event",
              ),
              _buildRsvpOption(
                status: InstanceMemberStatus.no,
                icon: Icons.cancel,
                title: "Can't make it",
                subtitle: "You won't get further updates",
              ),
              // const SizedBox(height: 16),
              // const Divider(),
              // Padding(
              //   padding: const EdgeInsets.symmetric(vertical: 16),
              //   child: Column(
              //     crossAxisAlignment: CrossAxisAlignment.start,
              //     children: [
              //       Text(
              //         'Add a Note (Optional)',
              //         style: TextStyle(
              //           color: Theme.of(context).colorScheme.onSurfaceVariant,
              //         ),
              //       ),
              //       const SizedBox(height: 8),
              //       TextFormField(
              //         controller: _noteController,
              //         decoration: InputDecoration(
              //           hintText: 'e.g., "Bringing snacks!" or "Running late"',
              //           filled: true,
              //           fillColor: Theme.of(context)
              //               .colorScheme
              //               .surfaceVariant
              //               .withOpacity(0.3),
              //         ),
              //         maxLines: 2,
              //       ),
              //     ],
              //   ),
              // ),
              if (widget.selectedStatus != null) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    widget.onRemoveRsvp();
                    Navigator.pop(context);
                  },
                  child: const Text("Remove RSVP"),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
