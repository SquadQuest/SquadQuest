import 'package:flutter/material.dart';

class OnboardingNotifications extends StatelessWidget {
  final VoidCallback onNext;

  const OnboardingNotifications({
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
            Icons.notifications_outlined,
            size: 64,
          ),
          const SizedBox(height: 24),
          const Text(
            'Stay Updated',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Enable notifications to stay informed about your events and friend activities',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: onNext,
            child: const Text('Enable Notifications'),
          ),
        ],
      ),
    );
  }
}
