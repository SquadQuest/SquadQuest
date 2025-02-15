import 'package:flutter/material.dart';

class OnboardingTopics extends StatelessWidget {
  final VoidCallback onNext;

  const OnboardingTopics({
    super.key,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.interests_outlined,
            size: 64,
          ),
          const SizedBox(height: 24),
          const Text(
            'Choose Your Interests',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select topics you\'re interested in to personalize your event recommendations',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: onNext,
            child: const Text('Choose Topics'),
          ),
        ],
      ),
    );
  }
}
