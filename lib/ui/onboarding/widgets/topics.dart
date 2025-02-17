import 'package:flutter/material.dart';
import 'package:squadquest/logger.dart';

enum TopicSelectionState {
  deselected,
  showInFeed,
  notifyImmediately,
}

class OnboardingTopics extends StatefulWidget {
  final VoidCallback onNext;

  const OnboardingTopics({
    super.key,
    required this.onNext,
  });

  @override
  State<OnboardingTopics> createState() => _OnboardingTopicsState();
}

class _OnboardingTopicsState extends State<OnboardingTopics> {
  // Mock topics for testing
  final _mockTopics = [
    'music.jazz',
    'music.house',
    'party.heads',
    'bike.joyrides',
    'music.rock',
    'music.electronic',
    'party.casual',
    'bike.racing',
    'music.classical',
    'music.indie',
    'party.themed',
    'bike.mountain',
  ];

  final _topicStates = <String, TopicSelectionState>{};

  void _cycleTopicState(String topic) {
    setState(() {
      final currentState =
          _topicStates[topic] ?? TopicSelectionState.deselected;
      _topicStates[topic] = switch (currentState) {
        TopicSelectionState.deselected => TopicSelectionState.showInFeed,
        TopicSelectionState.showInFeed => TopicSelectionState.notifyImmediately,
        TopicSelectionState.notifyImmediately => TopicSelectionState.deselected,
      };
    });
  }

  Widget _buildTopicIcon(TopicSelectionState state) {
    return switch (state) {
      TopicSelectionState.deselected =>
        const Icon(Icons.check_box_outline_blank),
      TopicSelectionState.showInFeed => const Icon(Icons.check_box_outlined),
      TopicSelectionState.notifyImmediately =>
        const Icon(Icons.notifications_active_outlined),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'What do you want to do more of with your friends?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 16),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.notifications_active_outlined),
            SizedBox(width: 4),
            Text('Notify immediately'),
            SizedBox(width: 16),
            Icon(Icons.check_box_outlined),
            SizedBox(width: 4),
            Text('Show in my feed'),
          ],
        ),
        const SizedBox(height: 16),
        // Scrollable topic list
        Expanded(
          child: Card(
            elevation: 2,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _mockTopics.length,
              itemBuilder: (context, index) {
                final topic = _mockTopics[index];
                final state =
                    _topicStates[topic] ?? TopicSelectionState.deselected;
                return ListTile(
                  onTap: () => _cycleTopicState(topic),
                  leading: _buildTopicIcon(state),
                  title: Text(topic),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {
            log('Selected topics: ${_topicStates.entries.where((e) => e.value != TopicSelectionState.deselected).map((e) => '${e.key}=${e.value}')}');
            widget.onNext();
          },
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
