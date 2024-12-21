import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/models/topic.dart';

class HomeOnboardingScreen extends ConsumerWidget {
  final Set<TopicID> selectedTopics;

  const HomeOnboardingScreen({
    super.key,
    required this.selectedTopics,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      title: 'Your Feed',
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome to your personalized feed!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Here\'s what\'s happening in your area based on your interests.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              // Mock upcoming events
              _buildEventCard(
                title: 'Weekend Hiking at Mount Tam',
                topic: 'Hiking',
                date: 'This Saturday at 9:00 AM',
                attendees: 5,
                context: context,
              ),
              const SizedBox(height: 16),
              _buildEventCard(
                title: 'Board Game Night at Mission Bay',
                topic: 'Board Games',
                date: 'Next Tuesday at 7:00 PM',
                attendees: 8,
                context: context,
              ),
              const SizedBox(height: 16),
              _buildEventCard(
                title: 'Photography Walk: Golden Gate',
                topic: 'Photography',
                date: 'Next Sunday at 4:00 PM',
                attendees: 3,
                context: context,
              ),
              const SizedBox(height: 32),
              // Invite friends section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Better with friends',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Invite your friends to join you on these adventures!',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        // TODO: Implement invite flow
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('Invite Friends'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Implement create event flow
        },
        icon: const Icon(Icons.add),
        label: const Text('Create Event'),
      ),
    );
  }

  Widget _buildEventCard({
    required String title,
    required String topic,
    required String date,
    required int attendees,
    required BuildContext context,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(topic),
                  backgroundColor:
                      Theme.of(context).colorScheme.secondaryContainer,
                ),
                const Spacer(),
                Text(
                  '$attendees going',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              date,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    // TODO: Implement view details
                  },
                  child: const Text('View Details'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    // TODO: Implement RSVP
                  },
                  child: const Text('I\'m Interested'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
