import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storybook_toolkit/storybook_toolkit.dart';

import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/topic_memberships.dart';
import 'package:squadquest/controllers/settings.dart';

import 'package:squadquest/screens/topics.dart';
import 'package:squadquest/storybook/screens/onboarding/welcome.dart';
import 'package:squadquest/storybook/screens/onboarding/home.dart';
import 'package:squadquest/storybook/screens/onboarding/permission_notification.dart';
import 'package:squadquest/storybook/screens/onboarding/permission_banner.dart';
import 'package:squadquest/storybook/screens/onboarding/friend_finder.dart';
import 'package:squadquest/storybook/screens/events/create_event.dart';
import 'package:squadquest/storybook/screens/events/event_details.dart';
import 'package:squadquest/storybook/screens/events/rsvp_interactions.dart';
import 'package:squadquest/storybook/screens/events/event_chat.dart';
import 'package:squadquest/storybook/screens/profile/edit_profile.dart';
import 'package:squadquest/storybook/screens/friends/friends_list.dart';
import 'package:squadquest/storybook/screens/topics/topics_list.v1.dart';
import 'package:squadquest/storybook/screens/topics/topics_list.v2.dart';
import 'package:squadquest/storybook/screens/home/home_screen.v1.dart';

import 'mocks.dart';

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
              name: 'Onboarding/Friend Finder',
              description:
                  'Help users connect with friends already using the app',
              builder: (context) => const FriendFinderScreen(),
            ),
            Story(
              name: 'Onboarding/Notification Banner',
              description:
                  'Banner you might see on screens if you denied notification permission',
              builder: (context) => const MockScreenWithNotificationBanner(),
            ),

            // Home Screen
            Story(
              name: 'Home/Main v1',
              description: 'Improved home screen with modern event filtering',
              builder: (context) => const HomeScreenV1(),
            ),

            // Event screens
            Story(
              name: 'Events/Create Event',
              description:
                  'Improved event creation form with better organization',
              builder: (context) => const CreateEventScreen(),
            ),
            Story(
              name: 'Events/Event Details',
              description: 'Improved event details screen with modern layout',
              builder: (context) => const EventDetailsScreen(),
            ),
            Story(
              name: 'Events/RSVP Interactions',
              description: 'Interactive demo of RSVP and menu interactions',
              builder: (context) => const RsvpInteractionsScreen(),
            ),
            Story(
              name: 'Events/Event Chat',
              description: 'Improved event chat with modern messaging features',
              builder: (context) => const EventChatScreen(),
            ),

            // Profile screens
            Story(
              name: 'Profile/Create Profile',
              description: 'Initial profile setup with welcome message',
              builder: (context) => const EditProfileScreen(isNewProfile: true),
            ),
            Story(
              name: 'Profile/Edit Profile',
              description: 'Profile editing for existing users',
              builder: (context) =>
                  const EditProfileScreen(isNewProfile: false),
            ),

            // Friends screens
            Story(
              name: 'Friends/Friends List',
              description: 'Improved friends list with requests and status',
              builder: (context) => const FriendsListScreen(),
            ),

            // Topics screens
            Story(
              name: 'Topics/Topics List v1',
              description: 'Improved topics browser with grid layout',
              builder: (context) => const TopicsListScreenV1(),
            ),
            Story(
              name: 'Topics/Topics List v2',
              description: 'With search',
              builder: (context) => const TopicsListScreenV2(),
            ),
          ],
        ));
  }
}
