import 'package:flutter/material.dart';

import 'package:squadquest/logger.dart';

class OnboardingLocation extends StatelessWidget {
  final VoidCallback onNext;

  const OnboardingLocation({
    super.key,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.center,
          child: Icon(
            Icons.location_on_outlined,
            size: 48,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'SquadQuest is great on the move',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 32),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: const [
                ListTile(
                  leading: Icon(Icons.map_outlined),
                  minLeadingWidth: 0,
                  title: Text(
                    'You can share your live location on a map with friends (only) who are going to the same event',
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.timer_outlined),
                  minLeadingWidth: 0,
                  title: Text('Trails deleted permanently after 3 hours'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {
            log('Enabling location sharing');
            onNext();
          },
          child: const Text('Allow location sharing'),
        ),
        TextButton(
          onPressed: onNext,
          child: const Text('Skip'),
        ),
      ],
    );
  }
}
