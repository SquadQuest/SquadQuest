import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/controllers/topic_memberships.dart';
import 'package:squadquest/models/topic.dart';
import 'package:squadquest/models/topic_member.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final Set<TopicID> selectedTopics = {};

  @override
  Widget build(BuildContext context) {
    final topicMembershipsList = ref.watch(topicMembershipsProvider);

    return AppScaffold(
      title: 'Welcome to SquadQuest',
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Find your squad, plan your next adventure',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'SquadQuest helps you discover and organize activities with friends who share your interests.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              const Text(
                'What are some things you want to do more with your friends?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              topicMembershipsList.when(
                data: (topicMemberships) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: topicMemberships.map((membership) {
                    final isSelected =
                        selectedTopics.contains(membership.topic.id);
                    return FilterChip(
                      label: Text(membership.topic.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            selectedTopics.add(membership.topic.id!);
                          } else {
                            selectedTopics.remove(membership.topic.id);
                          }
                        });
                      },
                      showCheckmark: false,
                      selectedColor:
                          Theme.of(context).colorScheme.primaryContainer,
                    );
                  }).toList(),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: Text('Error: $error'),
                ),
              ),
              const SizedBox(height: 32),
              if (selectedTopics.isNotEmpty) ...[
                Center(
                  child: FilledButton(
                    onPressed: () {
                      // This would navigate to the next screen in the real app
                      // but we don't need it in storybook mode
                    },
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
