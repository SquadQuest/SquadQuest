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
    'Music > Jazz',
    'Music > House',
    'Park > Picnic',
    'Bike > Joy Ride',
    'Music > Rock',
    'Music > Electronic',
    'Party > Casual',
    'Bike > Racing',
    'Music > Classical',
    'Music > Indie',
    'Party > Themed',
    'Bike > Mountain',
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
        Row(
          children: const [
            SizedBox(width: 16),
            Icon(
              Icons.interests_outlined,
              size: 48,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                'What do you want to do more of with your friends?',
                style: TextStyle(fontSize: 16),
              ),
            ),
            SizedBox(width: 16),
          ],
        ),
        const SizedBox(height: 32),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: Card(
                  elevation: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          'Most popular topics (find more after you\'re in)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _mockTopics.length,
                          itemBuilder: (context, index) {
                            final topic = _mockTopics[index];
                            final state = _topicStates[topic] ??
                                TopicSelectionState.deselected;
                            return ListTile(
                              onTap: () => _cycleTopicState(topic),
                              leading: _buildTopicIcon(state),
                              title: Text(topic),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.check_box_outlined, size: 16),
                  SizedBox(width: 4),
                  Text('Show in my feed', style: TextStyle(fontSize: 12)),
                  SizedBox(width: 16),
                  Icon(Icons.notifications_active_outlined, size: 16),
                  SizedBox(width: 4),
                  Text('Notify immediately', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {
            log('Selected topics: ${_topicStates.entries.where((e) => e.value != TopicSelectionState.deselected).map((e) => '${e.key}=${e.value}')}');
            widget.onNext();
          },
          child: const Text('Save my topics'),
        ),
        TextButton(
          onPressed: widget.onNext,
          child: const Text('Skip'),
        ),
      ],
    );
  }
}
