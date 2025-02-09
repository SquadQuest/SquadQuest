import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/instances.dart';
import 'package:squadquest/controllers/profile.dart';
import 'package:squadquest/ui/login/login_screen.dart';
import 'package:squadquest/ui/verify/verify_screen.dart';
import 'package:squadquest/ui/profile_form/profile_form_screen.dart';
import 'package:squadquest/ui/profile/profile_screen.dart';
import 'package:squadquest/ui/home/home_screen.dart';
import 'package:squadquest/ui/settings/screens/settings_screen.dart';
import 'package:squadquest/ui/event_form/event_form_screen.dart';
import 'package:squadquest/ui/event/event_screen.dart';
import 'package:squadquest/ui/friends/friends_screen.dart';
import 'package:squadquest/ui/map/map_screen.dart';
import 'package:squadquest/ui/topics/topics_screen.dart';
import 'package:squadquest/models/instance.dart';

final navigatorKey = GlobalKey<NavigatorState>();

// Initialize with platform's initial route if provided
String _initialLocation = PlatformDispatcher.instance.defaultRouteName != '/'
    ? PlatformDispatcher.instance.defaultRouteName
    : '/';

class RouterService {
  final Ref ref;

  RouterService(this.ref);

  late final router = GoRouter(
    initialLocation: '/',
    navigatorKey: navigatorKey,
    observers: [SentryNavigatorObserver()],
    redirect: _redirect,
    routes: [
      GoRoute(
        name: 'login',
        path: '/login',
        builder: (context, state) =>
            LoginScreen(redirect: state.uri.queryParameters['redirect']),
      ),
      GoRoute(
        name: 'verify',
        path: '/verify',
        builder: (context, state) =>
            VerifyScreen(redirect: state.uri.queryParameters['redirect']),
      ),
      GoRoute(
        name: 'profile-edit',
        path: '/profile',
        builder: (context, state) =>
            ProfileFormScreen(redirect: state.uri.queryParameters['redirect']),
      ),
      GoRoute(
        name: 'profile-view',
        path: '/profiles/:id',
        builder: (context, state) =>
            ProfileScreen(userId: state.pathParameters['id']!),
      ),
      GoRoute(
        name: 'home',
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        name: 'settings',
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        name: 'post-event',
        path: '/post-event',
        builder: (context, state) => EventEditScreen(
            duplicateEventId: state.uri.queryParameters['duplicateEventId']),
      ),
      GoRoute(
        name: 'event-details',
        path: '/events/:id',
        builder: (context, GoRouterState state) =>
            EventScreen(eventId: state.pathParameters['id']!),
      ),
      GoRoute(
        name: 'event-edit',
        path: '/events/:id/edit',
        builder: (context, GoRouterState state) =>
            EventEditScreen(instanceId: state.pathParameters['id']!),
      ),
      GoRoute(
        name: 'friends',
        path: '/friends',
        builder: (context, state) => const FriendsScreen(),
      ),
      GoRoute(
        name: 'map',
        path: '/map',
        builder: (context, state) => const MapScreen(),
      ),
      GoRoute(
        name: 'topics',
        path: '/topics',
        builder: (context, state) => const TopicsScreen(),
      ),
    ],
  );

  String? _redirect(BuildContext context, GoRouterState state) {
    // continue if route is login or verify
    if (state.topRoute?.name == 'login' || state.topRoute?.name == 'verify') {
      return null;
    }

    // continue unauthenticated if on a public event details screen
    if (state.topRoute?.name == 'event-details' &&
        state.pathParameters['id'] != null) {
      try {
        final event =
            ref.read(eventDetailsProvider(state.pathParameters['id']!));
        if (event.value?.visibility == InstanceVisibility.public) {
          return null;
        }
      } catch (error) {
        logger.e('error fetching event details', error: error);
      }
    }

    // redirect to login if not authenticated
    final redirect = state.uri.toString();
    return state.namedLocation('login',
        queryParameters: redirect == '/'
            ? {}
            : {
                'redirect': redirect,
              });
  }

  void goInitialLocation([String? overrideLocation]) {
    final location = overrideLocation ?? _initialLocation;
    router.go(location);
    _initialLocation = '/';
  }
}

final routerProvider = Provider((ref) => RouterService(ref));
