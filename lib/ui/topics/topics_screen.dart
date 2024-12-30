import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/controllers/topic_memberships.dart';
import 'package:squadquest/models/topic.dart';
import 'package:squadquest/models/topic_member.dart';

import 'widgets/topics_list.dart';

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
    final topicMembershipsList = ref.watch(topicMembershipsProvider);

    return AppScaffold(
      title: 'Topic Subscriptions',
      body: topicMembershipsList.when(
        error: (error, __) => Center(child: Text(error.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
        data: (topicMemberships) => RefreshIndicator(
          onRefresh: () async {
            return ref.read(topicMembershipsProvider.notifier).refresh();
          },
          child: CustomScrollView(
            slivers: [
              // Description
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Select topics you are interested in to receive notifications when new events are posted',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(179),
                        ),
                  ),
                ),
              ),

              // Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: TextFormField(
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      labelText: 'Search topics',
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (String searchQuery) {
                      setState(() {
                        _searchQuery = searchQuery;
                      });
                    },
                  ),
                ),
              ),

              // Topics List
              SliverToBoxAdapter(
                child: TopicsList(
                  topics: topicMemberships,
                  pendingChanges: pendingChanges,
                  onTopicToggle: _onTopicCheckboxChanged,
                  searchQuery: _searchQuery,
                ),
              ),

              // Bottom Padding
              const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
            ],
          ),
        ),
      ),
    );
  }

  void _onTopicCheckboxChanged(
      MyTopicMembership topicMembership, bool? value) async {
    // mark as pending
    setState(() {
      pendingChanges[topicMembership.topic.id!] = value == true;
    });

    try {
      await ref
          .read(topicMembershipsProvider.notifier)
          .saveSubscribed(topicMembership, value == true);
    } finally {
      // unmark as pending
      setState(() {
        pendingChanges.remove(topicMembership.topic.id);
      });
    }
  }
}
