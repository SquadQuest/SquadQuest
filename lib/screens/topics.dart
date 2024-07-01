import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grouped_list/grouped_list.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/topic_memberships.dart';
import 'package:squadquest/models/topic.dart';
import 'package:squadquest/models/topic_member.dart';

class TopicsScreen extends ConsumerStatefulWidget {
  const TopicsScreen({super.key});

  @override
  ConsumerState<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends ConsumerState<TopicsScreen> {
  final Map<TopicID, bool> pendingChanges = {};

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);
    final topicMembershipsList = ref.watch(topicMembershipsProvider);

    if (session == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return AppScaffold(
      title: 'Topic Subscriptions',
      body: Column(children: [
        const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
                'Select topics you are interested in to receive notifications when new events are posted',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic))),
        Expanded(
            child: RefreshIndicator(
          onRefresh: () async {
            return ref.read(topicMembershipsProvider.notifier).refresh();
          },
          child: topicMembershipsList.when(
              data: (topicMemberships) {
                return GroupedListView(
                  elements: topicMemberships,
                  physics: const AlwaysScrollableScrollPhysics(),
                  useStickyGroupSeparators: true,
                  stickyHeaderBackgroundColor:
                      Theme.of(context).scaffoldBackgroundColor,
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
                      )),
                  itemBuilder: (context, topicMembership) {
                    return CheckboxListTile(
                      title: Text(topicMembership.topic.name),
                      enabled:
                          !pendingChanges.containsKey(topicMembership.topic.id),
                      value: pendingChanges[topicMembership.topic.id] ??
                          topicMembership.subscribed,
                      onChanged: (newValue) =>
                          _onTopicCheckboxChanged(topicMembership, newValue),
                      subtitle: topicMembership.events != null &&
                              topicMembership.events! > 0
                          ? Text('${topicMembership.events} events')
                          : null,
                    );
                  },
                  itemComparator: (topicMembership1, topicMembership2) =>
                      topicMembership1.events == topicMembership2.events
                          ? topicMembership1.topic.name
                              .compareTo(topicMembership2.topic.name)
                          : topicMembership1.events == null ||
                                  topicMembership2.events == null
                              ? 0
                              : topicMembership2.events!
                                  .compareTo(topicMembership1.events!),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  Center(child: Text('Error: $error'))),
        ))
      ]),
    );
  }

  void _onTopicCheckboxChanged(
      MyTopicMembership topicMembership, bool? value) async {
    // mark as pending
    setState(() {
      pendingChanges[topicMembership.topic.id!] = value == true;
    });

    // write to database
    try {
      await ref
          .read(topicMembershipsProvider.notifier)
          .saveSubscribed(topicMembership, value == true);
    } catch (error) {
      loggerWithStack.e(error);
    }

    // unmark as pending
    setState(() {
      pendingChanges.remove(topicMembership.topic.id);
    });
  }
}
