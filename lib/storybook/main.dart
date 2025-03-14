import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storybook_toolkit/storybook_toolkit.dart';

import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/topic_memberships.dart';
import 'package:squadquest/controllers/settings.dart';

import 'package:squadquest/storybook/screens/onboarding/welcome.dart';
import 'package:squadquest/storybook/screens/onboarding/home.dart';
import 'package:squadquest/storybook/screens/onboarding/permission_notification.dart';
import 'package:squadquest/storybook/screens/onboarding/permission_banner.dart';
import 'package:squadquest/storybook/screens/onboarding/friend_finder.dart';
import 'package:squadquest/storybook/screens/events/create_event.dart';
import 'package:squadquest/storybook/screens/events/event_details.dart';
import 'package:squadquest/storybook/screens/events/event_details.v2.dart';
import 'package:squadquest/storybook/screens/events/event_details.v3.dart';
import 'package:squadquest/storybook/screens/events/rsvp_interactions.dart';
import 'package:squadquest/storybook/screens/events/rsvp_interactions.v2.dart';
import 'package:squadquest/storybook/screens/events/event_chat.dart';
import 'package:squadquest/storybook/screens/events/attendees_demo.dart';
import 'package:squadquest/storybook/screens/profile/edit_profile.dart';
import 'package:squadquest/storybook/screens/friends/friends_list.dart';
import 'package:squadquest/storybook/screens/communities/communities_list.dart';
import 'package:squadquest/storybook/screens/communities/communities_list.v2.dart';
import 'package:squadquest/storybook/screens/communities/community_details.dart';
import 'package:squadquest/storybook/screens/communities/create_community.dart';
import 'package:squadquest/storybook/screens/venues/venue_profile.dart';
import 'package:squadquest/storybook/screens/topics/topics_list.v1.dart';
import 'package:squadquest/storybook/screens/topics/topics_list.v2.dart';
import 'package:squadquest/storybook/screens/home/home_screen.v1.dart';
import 'package:squadquest/storybook/screens/home/home_screen.v2.dart';
import 'package:squadquest/storybook/screens/settings/settings_screen.dart';
import 'package:squadquest/storybook/screens/drawer/drawer_demo.dart';
import 'package:squadquest/storybook/screens/about.dart';

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

            // Communities screens
            Story(
              name: 'Communities/Communities List v1',
              description: 'Browse and join local interest-based communities',
              builder: (context) => const CommunitiesListScreen(),
            ),
            Story(
              name: 'Communities/Communities List v2',
              description:
                  'Enhanced browsing with categories and activity feed',
              builder: (context) => const CommunitiesListV2Screen(),
            ),
            Story(
              name: 'Communities/Community Details',
              description:
                  'Detailed view of a community with events and activities',
              builder: (context) => const CommunityDetailsScreen(),
            ),
            Story(
              name: 'Communities/Create Community',
              description:
                  'Create a new community with recurring events and venue partnerships',
              builder: (context) => const CreateCommunityScreen(),
            ),

            // Venue screens
            Story(
              name: 'Communities/Venues/Venue Profile',
              description:
                  'Venue dashboard showing analytics and hosting benefits',
              builder: (context) => const VenueProfileScreen(),
            ),

            // Navigation
            Story(
              name: 'Redesign/Navigation/Drawer',
              description:
                  'Redesigned navigation drawer with modern layout and grouping',
              builder: (context) => const DrawerDemoScreen(),
            ),

            // Home Screen
            Story(
              name: 'Redesign/Home/Main v1',
              description: 'Improved home screen with modern event filtering',
              builder: (context) => const HomeScreenV1(),
            ),
            Story(
              name: 'Redesign/Home/Main v2',
              description: 'With additional event details',
              builder: (context) => const HomeScreenV2(),
            ),

            // Event screens
            Story(
              name: 'Redesign/Events/Create Event',
              description:
                  'Improved event creation form with better organization',
              builder: (context) => const CreateEventScreen(),
            ),
            Story(
              name: 'Redesign/Events/Event Details v1',
              description: 'Improved event details screen with modern layout',
              builder: (context) => const EventDetailsScreen(),
            ),
            Story(
              name: 'Redesign/Events/Event Details v2',
              description: 'Expanded attendees list with RSVP grouping',
              builder: (context) => const EventDetailsV2Screen(),
            ),
            Story(
              name: 'Redesign/Events/Event Details v3',
              description:
                  'Combined design with overlay header and detailed attendees',
              builder: (context) => const EventDetailsV3Screen(),
            ),
            Story(
              name: 'Redesign/Events/RSVP Interactions v1',
              description: 'Interactive demo of RSVP and menu interactions',
              builder: (context) => const RsvpInteractionsScreen(),
            ),
            Story(
              name: 'Redesign/Events/RSVP Interactions v2',
              description: 'RSVP flow with optional notes',
              builder: (context) => const RsvpInteractionsV2Screen(),
            ),
            Story(
              name: 'Redesign/Events/Event Chat',
              description: 'Improved event chat with modern messaging features',
              builder: (context) => const EventChatScreen(),
            ),
            Story(
              name: 'Redesign/Events/Attendees List',
              description: 'Attendee list with search and filtering',
              builder: (context) => const AttendeesDemoScreen(),
            ),

            // Profile & Settings screens
            Story(
              name: 'Redesign/Profile/Create Profile',
              description: 'Initial profile setup with welcome message',
              builder: (context) => const EditProfileScreen(isNewProfile: true),
            ),
            Story(
              name: 'Redesign/Profile/Edit Profile',
              description: 'Profile editing for existing users',
              builder: (context) =>
                  const EditProfileScreen(isNewProfile: false),
            ),
            Story(
              name: 'Redesign/Profile/Settings',
              description:
                  'Redesigned settings with modern layout and grouping',
              builder: (context) => const SettingsScreen(),
            ),

            // Friends screens
            Story(
              name: 'Redesign/Friends/Friends List',
              description: 'Improved friends list with requests and status',
              builder: (context) => const FriendsListScreen(),
            ),

            // Topics screens
            Story(
              name: 'Redesign/Topics/Topics List v1',
              description: 'Improved topics browser with grid layout',
              builder: (context) => const TopicsListScreenV1(),
            ),
            Story(
              name: 'Redesign/Topics/Topics List v2',
              description: 'With search',
              builder: (context) => const TopicsListScreenV2(),
            ),
            Story(
              name: 'About',
              description: 'About screen with starfield background and logo',
              builder: (context) => const AboutScreen(),
            ),
          ],
        ));
  }
}
