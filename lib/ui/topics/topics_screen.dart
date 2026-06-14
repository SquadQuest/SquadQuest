import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/topic_memberships.dart';
import 'package:squadquest/models/topic.dart';
import 'package:squadquest/models/topic_member.dart';

import 'widgets/topic_list_section.dart';

class TopicsScreen extends ConsumerStatefulWidget {
  const TopicsScreen({super.key});

  @override
  ConsumerState<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends ConsumerState<TopicsScreen> {
  String _searchQuery = '';
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
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Select topics you are interested in to receive notifications when new events are posted',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
            ),
          ),
          TextFormField(
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search topics',
            ),
            onChanged: (String searchQuery) {
              setState(() {
                _searchQuery = searchQuery.toLowerCase();
              });
            },
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                return ref.read(topicMembershipsProvider.notifier).refresh();
              },
              child: topicMembershipsList.when(
                data: (topicMemberships) => TopicListSection(
                  topicMemberships: topicMemberships,
                  pendingChanges: pendingChanges,
                  searchQuery: _searchQuery,
                  onTopicChanged: _onTopicCheckboxChanged,
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) =>
                    Center(child: Text('Error: $error')),
              ),
            ),
          ),
        ],
      ),
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
