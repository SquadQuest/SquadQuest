import 'package:flutter/material.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:squadquest/models/topic_member.dart';

class TopicListSection extends StatelessWidget {
  final List<MyTopicMembership> topicMemberships;
  final Map<String, bool> pendingChanges;
  final String searchQuery;
  final Function(MyTopicMembership, bool?) onTopicChanged;

  const TopicListSection({
    super.key,
    required this.topicMemberships,
    required this.pendingChanges,
    required this.searchQuery,
    required this.onTopicChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filteredTopicMemberships = topicMemberships.where((topicMembership) {
      return searchQuery.isEmpty ||
          topicMembership.topic.name.toLowerCase().contains(searchQuery);
    }).toList();

    return GroupedListView(
      elements: filteredTopicMemberships,
      physics: const AlwaysScrollableScrollPhysics(),
      useStickyGroupSeparators: true,
      stickyHeaderBackgroundColor: Theme.of(context).scaffoldBackgroundColor,
      groupBy: (topicMembership) =>
          pendingChanges.containsKey(topicMembership.topic.id)
              ? pendingChanges[topicMembership.topic.id]!
              : topicMembership.subscribed,
      groupComparator: (group1, group2) {
        if (group1 == group2) return 0;
        return group1 ? -1 : 1;
      },
      groupSeparatorBuilder: (bool group) => Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          group ? 'Subscribed' : 'Available',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
        ),
      ),
      itemBuilder: (context, topicMembership) {
        final topicName = topicMembership.topic.name;
        int? matchIndex;

        if (searchQuery.isNotEmpty) {
          matchIndex =
              topicName.toLowerCase().indexOf(searchQuery.toLowerCase());
          if (matchIndex == -1) {
            matchIndex = null;
          }
        }

        return CheckboxListTile(
          title: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyLarge,
              children: matchIndex == null
                  ? [TextSpan(text: topicName)]
                  : [
                      TextSpan(text: topicName.substring(0, matchIndex)),
                      TextSpan(
                        text: topicName.substring(
                            matchIndex, matchIndex + searchQuery.length),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: topicName
                            .substring(matchIndex + searchQuery.length),
                      ),
                    ],
            ),
          ),
          enabled: !pendingChanges.containsKey(topicMembership.topic.id),
          value: pendingChanges[topicMembership.topic.id] ??
              topicMembership.subscribed,
          onChanged: (newValue) => onTopicChanged(topicMembership, newValue),
          subtitle:
              topicMembership.events != null && topicMembership.events! > 0
                  ? Text('${topicMembership.events} events')
                  : null,
        );
      },
      itemComparator: (topicMembership1, topicMembership2) => topicMembership1
                  .events ==
              topicMembership2.events
          ? topicMembership1.topic.name.compareTo(topicMembership2.topic.name)
          : topicMembership1.events == null || topicMembership2.events == null
              ? 0
              : topicMembership2.events!.compareTo(topicMembership1.events!),
    );
  }
}
