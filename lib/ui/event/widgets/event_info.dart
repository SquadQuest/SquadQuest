import 'package:flutter/material.dart';

class EventInfo extends StatelessWidget {
  final String description;
  final String host;
  final String startTime;
  final String? endTime;
  final String visibility;
  final String topic;

  const EventInfo({
    super.key,
    required this.description,
    required this.host,
    required this.startTime,
    this.endTime,
    required this.visibility,
    required this.topic,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          title: 'About',
          child: Text(
            description,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: 'Event Info',
          child: Column(
            children: [
              _buildInfoRow(
                context,
                icon: Icons.person,
                label: 'Posted by',
                value: host,
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                context,
                icon: Icons.schedule,
                label: 'Time',
                value: 'Starts between $startTime',
                secondaryValue: endTime != null ? 'Ends around $endTime' : null,
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                context,
                icon: Icons.visibility,
                label: 'Visibility',
                value: visibility,
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                context,
                icon: Icons.category,
                label: 'Topic',
                value: topic,
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
