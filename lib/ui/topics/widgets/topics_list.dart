import 'package:flutter/material.dart';
import 'package:squadquest/models/topic_member.dart';

class TopicsList extends StatelessWidget {
  final List<MyTopicMembership> topics;
  final Map<String, bool> pendingChanges;
  final Function(MyTopicMembership, bool?) onTopicToggle;
  final String searchQuery;

  const TopicsList({
    super.key,
    required this.topics,
    required this.pendingChanges,
    required this.onTopicToggle,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    final filteredTopics = topics.where((topic) {
      return topic.topic.name.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    if (filteredTopics.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.topic,
                size: 48,
                color: Theme.of(context).colorScheme.primary.withAlpha(128),
              ),
              const SizedBox(height: 16),
              Text(
                searchQuery.isEmpty
                    ? 'No topics available'
                    : 'No matching topics',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(179),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                searchQuery.isEmpty
                    ? 'Subscribe to topics to get notified about relevant events'
                    : 'Try a different search term',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(128),
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.topic,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Available Topics',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: filteredTopics.map((topic) {
              final isPending = pendingChanges.containsKey(topic.topic.id);
              return ListTile(
                title: Text(
                  topic.topic.name,
                  style: TextStyle(
                    color: isPending
                        ? Theme.of(context).colorScheme.onSurface.withAlpha(128)
                        : null,
                  ),
                ),
                trailing: isPending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Switch(
                        value:
                            pendingChanges[topic.topic.id] ?? topic.subscribed,
                        onChanged: (value) => onTopicToggle(topic, value),
                      ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
