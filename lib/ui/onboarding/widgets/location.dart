import 'package:flutter/material.dart';

class OnboardingLocation extends StatelessWidget {
  final VoidCallback onNext;

  const OnboardingLocation({
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
            Icons.location_on_outlined,
            size: 64,
          ),
          const SizedBox(height: 24),
          const Text(
            'Find Local Events',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Allow location access to discover events and activities happening near you',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: onNext,
            child: const Text('Enable Location'),
          ),
        ],
      ),
    );
  }
}
