import 'package:flutter/material.dart';

import 'package:squadquest/app_scaffold.dart';
import 'widgets/notifications.dart';
import 'widgets/location.dart';
import 'widgets/topics.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  void _goToLocationStep() {
    if (mounted) {
      _navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => AppScaffold(
            title: 'Location Access',
            showLocationSharingSheet: false,
            bodyPadding: const EdgeInsets.all(24),
            body: OnboardingLocation(
              onNext: _goToTopicsStep,
            ),
          ),
        ),
      );
    }
  }

  void _goToTopicsStep() {
    if (mounted) {
      _navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => AppScaffold(
            title: 'Choose Topics',
            showLocationSharingSheet: false,
            bodyPadding: const EdgeInsets.all(24),
            body: OnboardingTopics(
              onNext: () {
                // TODO: Handle completion
              },
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: _navigatorKey,
      pages: [
        MaterialPage(
          child: AppScaffold(
            title: 'Welcome to SquadQuest',
            showLocationSharingSheet: false,
            bodyPadding: const EdgeInsets.all(24),
            body: OnboardingNotifications(
              onNext: _goToLocationStep,
            ),
          ),
        ),
      ],
      onDidRemovePage: (Page<Object?> page) {},
    );
  }
}
