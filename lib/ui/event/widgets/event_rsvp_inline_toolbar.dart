import 'package:flutter/material.dart';
import 'package:squadquest/models/instance.dart';

class EventRsvpInlineToolbar extends StatefulWidget {
  final Function(InstanceMemberStatus status, String? note) onStatusSelected;

  const EventRsvpInlineToolbar({
    super.key,
    required this.onStatusSelected,
  });

  @override
  State<EventRsvpInlineToolbar> createState() => _EventRsvpInlineToolbarState();
}

class _EventRsvpInlineToolbarState extends State<EventRsvpInlineToolbar> {
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _handleSubmit(InstanceMemberStatus status, String note) {
    widget.onStatusSelected(status, note.trim().isEmpty ? null : note.trim());
  }

  Widget _buildRsvpOption({
    required InstanceMemberStatus status,
    required IconData icon,
    required String label,
  }) {
    return Builder(
      builder: (context) => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _handleSubmit(status, _noteController.text),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Anchor pointer row (matches quick actions layout)
        Positioned(
          top: -7,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Container(
                width: 64,
                alignment: Alignment.center,
                child: CustomPaint(
                  size: const Size(20, 10),
                  painter: _AnchorPainter(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
              const SizedBox(width: 64), // Map button
              const SizedBox(width: 64), // Chat button
              const SizedBox(width: 64), // Share button
            ],
          ),
        ),

        // Toolbar card
        Card(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          elevation: 3,
          margin: const EdgeInsets.fromLTRB(8, 2, 8, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  "You're invited! Can you make it?",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: TextFormField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    hintText: 'Include an optional note...',
                    isDense: true,
                    filled: true,
                    fillColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withAlpha(80),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withAlpha(80),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withAlpha(80),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    prefixIcon: Icon(
                      Icons.edit_note_outlined,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  style: const TextStyle(fontSize: 14),
                  maxLines: 1,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (note) {
                    // Don't submit on enter, let the buttons handle submission
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildRsvpOption(
                      status: InstanceMemberStatus.no,
                      icon: Icons.cancel,
                      label: "CAN'T GO",
                    ),
                    _buildRsvpOption(
                      status: InstanceMemberStatus.maybe,
                      icon: Icons.help,
                      label: "MAYBE",
                    ),
                    _buildRsvpOption(
                      status: InstanceMemberStatus.yes,
                      icon: Icons.check_circle,
                      label: "GOING",
                    ),
                    _buildRsvpOption(
                      status: InstanceMemberStatus.omw,
                      icon: Icons.directions_run,
                      label: "ON MY WAY",
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnchorPainter extends CustomPainter {
  final Color color;

  _AnchorPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_AnchorPainter oldDelegate) => color != oldDelegate.color;
}
