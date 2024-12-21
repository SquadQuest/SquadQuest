import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/topic_memberships.dart';

import 'package:squadquest/models/topic.dart';
import 'package:squadquest/models/topic_member.dart';

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
