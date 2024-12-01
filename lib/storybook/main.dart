import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:storybook_toolkit/storybook_toolkit.dart';
import 'package:squadquest/screens/topics.dart';
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
    return Storybook(
      stories: [
        Story(
            name: 'Topics Screen',
            builder: (context) => ProviderScope(
                  overrides: [
                    authControllerProvider.overrideWith(MockAuthController.new),
                    topicMembershipsProvider
                        .overrideWith(MockTopicMembershipsController.new),
                    storybookModeProvider.overrideWith((ref) => true),
                  ],
                  child: const TopicsScreen(),
                )),
      ],
    );
  }
}
