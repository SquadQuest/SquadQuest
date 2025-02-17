import 'package:flutter/material.dart';

import 'package:squadquest/logger.dart';

class OnboardingNotifications extends StatefulWidget {
  final VoidCallback onNext;

  const OnboardingNotifications({
    super.key,
    required this.onNext,
  });

  @override
  State<OnboardingNotifications> createState() =>
      _OnboardingNotificationsState();
}

class _OnboardingNotificationsState extends State<OnboardingNotifications> {
  bool _friendOutreach = true;
  bool _eventUpdates = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: const [
            SizedBox(width: 16),
            Icon(
              Icons.notifications_outlined,
              size: 48,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                'SquadQuest needs to show notifications to be most useful',
                style: TextStyle(fontSize: 16),
              ),
            ),
            SizedBox(width: 16),
          ],
        ),
        const SizedBox(height: 32),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                CheckboxListTile(
                  value: _friendOutreach,
                  onChanged: (value) =>
                      setState(() => _friendOutreach = value!),
                  title: const Text('Outreach from friends'),
                  secondary: const Icon(Icons.group_outlined),
                ),
                CheckboxListTile(
                  value: _eventUpdates,
                  onChanged: (value) => setState(() => _eventUpdates = value!),
                  title: const Text('Updates to your events'),
                  secondary: const Icon(Icons.event_outlined),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {
            log('Enabling notifications with preferences: '
                'friendOutreach=$_friendOutreach, '
                'eventUpdates=$_eventUpdates');
            widget.onNext();
          },
          child: const Text('Allow Notifications'),
        ),
        TextButton(
          onPressed: widget.onNext,
          child: const Text('Skip'),
        ),
      ],
    );
  }
}
