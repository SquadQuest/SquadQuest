import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storybook_toolkit/storybook_toolkit.dart';
import 'package:squadquest/screens/topics.dart';
import 'package:squadquest/screens/welcome.dart';
import 'package:squadquest/screens/home_onboarding.dart';
import 'package:squadquest/screens/notification_permission.dart';
import 'package:squadquest/screens/mock_screen_with_notification_banner.dart';
import 'package:squadquest/models/topic.dart';
import 'package:squadquest/models/topic_member.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/topic_memberships.dart';
import 'package:squadquest/controllers/settings.dart';
import 'package:squadquest/services/supabase.dart';

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
            Story(
              name: 'Notification Permission Screen',
              builder: (context) => const NotificationPermissionScreen(),
            ),
            Story(
              name: 'Welcome Screen',
              builder: (context) => const WelcomeScreen(),
            ),
            Story(
              name: 'Home Onboarding Screen',
              builder: (context) => HomeOnboardingScreen(
                selectedTopics: {'topic1', 'topic2', 'topic3'},
              ),
            ),
            Story(
              name: 'Topics Screen',
              builder: (context) => const TopicsScreen(),
            ),
            Story(
              name: 'Activity Feed with Notification Banner',
              builder: (context) => const MockScreenWithNotificationBanner(),
            ),
          ],
        ));
  }
}
