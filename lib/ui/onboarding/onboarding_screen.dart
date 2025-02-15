import 'package:flutter/material.dart';

import 'widgets/notifications.dart';
import 'widgets/location.dart';
import 'widgets/topics.dart';

enum OnboardingStep {
  notifications,
  location,
  topics,
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  OnboardingStep _currentStep = OnboardingStep.notifications;

  void _goToNextStep() {
    setState(() {
      switch (_currentStep) {
        case OnboardingStep.notifications:
          _currentStep = OnboardingStep.location;
        case OnboardingStep.location:
          _currentStep = OnboardingStep.topics;
        case OnboardingStep.topics:
          // TODO: Handle completion
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: switch (_currentStep) {
          OnboardingStep.notifications => OnboardingNotifications(
              onNext: _goToNextStep,
            ),
          OnboardingStep.location => OnboardingLocation(
              onNext: _goToNextStep,
            ),
          OnboardingStep.topics => OnboardingTopics(
              onNext: _goToNextStep,
            ),
        },
      ),
    );
  }
}
