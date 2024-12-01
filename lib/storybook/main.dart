import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storybook_toolkit/storybook_toolkit.dart';

import 'package:squadquest/models/topic.dart';
import 'package:squadquest/models/topic_member.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/topic_memberships.dart';
import 'package:squadquest/controllers/settings.dart';

import 'package:squadquest/screens/topics.dart';
import 'package:squadquest/storybook/screens/onboarding/welcome.dart';
import 'package:squadquest/storybook/screens/onboarding/home.dart';
import 'package:squadquest/storybook/screens/onboarding/permission_notification.dart';
import 'package:squadquest/storybook/screens/onboarding/permission_banner.dart';

// Mock Auth Controller
class MockAuthController extends AuthController {
  @override
  Session? build() => Session(
        accessToken: 'mock-token',
        tokenType: 'bearer',
        user: User(
          id: 'mock-user-id',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
}

// Mock Topic Memberships Controller
class MockTopicMembershipsController extends TopicMembershipsController {
  @override
  Future<List<MyTopicMembership>> build() async {
    return [
      MyTopicMembership(
        topic: Topic(
          id: 'topic1',
          name: 'Hiking',
        ),
        subscribed: true,
        events: 5,
      ),
      MyTopicMembership(
        topic: Topic(
          id: 'topic2',
          name: 'Photography',
        ),
        subscribed: false,
        events: 3,
      ),
      MyTopicMembership(
        topic: Topic(
          id: 'topic3',
          name: 'Board Games',
        ),
        subscribed: true,
        events: 2,
      ),
      MyTopicMembership(
        topic: Topic(
          id: 'topic4',
          name: 'Rock Climbing',
        ),
        subscribed: false,
        events: 0,
      ),
      MyTopicMembership(
        topic: Topic(
          id: 'topic5',
          name: 'Movie Nights',
        ),
        subscribed: false,
        events: 1,
      ),
      MyTopicMembership(
        topic: Topic(
          id: 'topic6',
          name: 'Cooking',
        ),
        subscribed: false,
        events: 0,
      ),
    ];
  }

  @override
  Future<MyTopicMembership> saveSubscribed(
      MyTopicMembership topicMembership, bool subscribed) async {
    // Mock implementation that just returns the updated membership
    return MyTopicMembership(
      topic: topicMembership.topic,
      subscribed: subscribed,
      events: topicMembership.events,
    );
  }
}

void main() {
  runApp(const ProviderScope(child: StorybookApp()));
}

class StorybookApp extends StatelessWidget {
  const StorybookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(MockAuthController.new),
          storybookModeProvider.overrideWith((ref) => true),
          topicMembershipsProvider
              .overrideWith(MockTopicMembershipsController.new),
        ],
        child: Storybook(
          plugins: initializePlugins(
            initialDeviceFrameData: (
              isFrameVisible: true,
              device: Devices.ios.iPhone12ProMax,
              orientation: Orientation.portrait
            ),
          ),
          stories: [
            // Real screens with mock data
            Story(
              name: 'Existing Screens/Topics Screen',
              description: 'The real topics screen with mock data',
              builder: (context) => const TopicsScreen(),
            ),

            // Mock onboarding screens
            Story(
              name: 'Onboarding/Welcome',
              description: 'An introductory screen you might see before login',
              builder: (context) => const WelcomeScreen(),
            ),
            Story(
              name: 'Onboarding/Notification Permission',
              description:
                  'An information-only notification permission precursor',
              builder: (context) => const NotificationPermissionScreen(),
            ),
            Story(
              name: 'Onboarding/Home',
              description: 'A simplified home screen concept',
              builder: (context) => HomeOnboardingScreen(
                selectedTopics: {'topic1', 'topic2', 'topic3'},
              ),
            ),
            Story(
              name: 'Onboarding/Notification Banner',
              description:
                  'Banner you might see on screens if you denied notification permission',
              builder: (context) => const MockScreenWithNotificationBanner(),
            ),
          ],
        ));
  }
}
