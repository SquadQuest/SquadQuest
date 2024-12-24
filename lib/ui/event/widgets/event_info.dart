import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/topic.dart';
import 'package:squadquest/models/user.dart';

class EventInfo extends StatefulWidget {
  final String? description;
  final UserProfile host;
  final DateTime startTimeMin;
  final DateTime startTimeMax;
  final DateTime? endTime;
  final InstanceVisibility visibility;
  final Topic? topic;

  const EventInfo({
    super.key,
    this.description,
    required this.host,
    required this.startTimeMin,
    required this.startTimeMax,
    this.endTime,
    required this.visibility,
    this.topic,
  });

  @override
  State<EventInfo> createState() => _EventInfoState();
}

class _EventInfoState extends State<EventInfo> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.description != null &&
            widget.description!.trim().isNotEmpty) ...[
          _buildSection(
            title: 'About',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.description!,
                  style: const TextStyle(fontSize: 16),
                  maxLines: _isExpanded ? null : 5,
                  overflow: _isExpanded ? null : TextOverflow.ellipsis,
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final textPainter = TextPainter(
                      text: TextSpan(
                        text: widget.description,
                        style: const TextStyle(fontSize: 16),
                      ),
                      maxLines: 5,
                      textDirection: TextDirection.ltr,
                    )..layout(maxWidth: constraints.maxWidth);

                    if (textPainter.didExceedMaxLines) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isExpanded = !_isExpanded;
                            });
                          },
                          child: Text(
                            _isExpanded ? 'Show less' : 'Show more',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        _buildSection(
          title: 'Event Info',
          child: Column(
            children: [
              _buildInfoRow(
                context,
                icon: Icons.person,
                label: 'Posted by',
                value: widget.host.displayName,
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                context,
                icon: Icons.schedule,
                label: 'Time',
                value:
                    'Starts between ${DateFormat('h:mm a').format(widget.startTimeMin)}-${DateFormat('h:mm a').format(widget.startTimeMax)}',
                secondaryValue: widget.endTime != null
                    ? 'Ends around ${DateFormat('h:mm a').format(widget.endTime!)}'
                    : null,
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                context,
                icon: Icons.visibility,
                label: 'Visibility',
                value: switch (widget.visibility) {
                  InstanceVisibility.private => 'Private event',
                  InstanceVisibility.friends => 'Friends-only event',
                  InstanceVisibility.public => 'Public event',
                },
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                context,
                icon: Icons.category,
                label: 'Topic',
                value: widget.topic?.name ?? '',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    String? secondaryValue,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (secondaryValue != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    secondaryValue,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }
}
