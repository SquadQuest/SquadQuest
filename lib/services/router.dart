import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/services/connection.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/instances.dart';
import 'package:squadquest/controllers/profile.dart';
import 'package:squadquest/screens/splash.dart';
import 'package:squadquest/screens/login.dart';
import 'package:squadquest/screens/verify.dart';
import 'package:squadquest/screens/profile_form.dart';
import 'package:squadquest/screens/profile.dart';
import 'package:squadquest/screens/home.dart';
import 'package:squadquest/screens/settings.dart';
import 'package:squadquest/ui/event_form/event_form_screen.dart';
import 'package:squadquest/ui/event/event_screen.dart';
import 'package:squadquest/screens/friends.dart';
import 'package:squadquest/ui/map/map_screen.dart';
import 'package:squadquest/screens/topics.dart';
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
    initialLocation: '/splash',
    navigatorKey: navigatorKey,
    observers: [SentryNavigatorObserver()],
    redirect: _redirect,
    routes: [
      GoRoute(
        name: 'splash',
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
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
            facebookUrl: state.uri.queryParameters['facebookUrl'],
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

  Future<String?> _redirect(BuildContext context, GoRouterState state) async {
    final splashComplete = ref.read(splashCompleteProvider);
    final session = ref.read(authControllerProvider);

    // continue if route is login, verify or splash
    if (state.topRoute?.name == 'login' ||
        state.topRoute?.name == 'verify' ||
        state.topRoute?.name == 'splash') {
      return null;
    }

    // save to initial route and return existing location if splash isn't finished
    if (!splashComplete) {
      // If we have a non-splash route, preserve it
      if (state.uri.toString() != '/splash') {
        _initialLocation = state.uri.toString();
      }

      final currentLocation =
          state.uri.toString() == '' ? '/splash' : state.matchedLocation;
      logger.d({
        'splash not complete, saving redirect to initialLocation': {
          'initialLocation': _initialLocation,
          'currentLocation': currentLocation,
        }
      });
      return currentLocation;
    }

    logger.d('processing redirect to ${state.uri.toString()}');

    // continue if user is authenticated
    if (session != null) {
      return null;
    }

    // continue unauthenticated if on a public event details screen
    if (state.topRoute?.name == 'event-details' &&
        state.pathParameters['id'] != null) {
      await supabaseInitialized;
      try {
        final event = await ref
            .read(eventDetailsProvider(state.pathParameters['id']!).future);

        // allow unauthenticated access to public events
        if (event.visibility == InstanceVisibility.public) {
          return null;
        }
      } catch (error) {
        logger.e('error fetching event details', error: error);
      }
    }

    // otherwise: redirect to login screen
    final redirect = state.uri.toString();
    return state.namedLocation('login',
        queryParameters: redirect == '/'
            ? {}
            : {
                'redirect': redirect,
              });
  }

  Future<void> goInitialLocation([String? overrideLocation]) async {
    final String initialLocation = overrideLocation ?? _initialLocation;
    final currentRouteName =
        router.routerDelegate.currentConfiguration.last.route.name;

    logger.t({
      'goInitialLocation': {
        'initialLocation': initialLocation,
        'currentRouteName': currentRouteName,
      }
    });

    // send user to profile screen if profile is not set
    final session = ref.read(authControllerProvider);
    if (session != null) {
      try {
        final profile = await ref.read(profileProvider.future);
        if (profile == null) {
          router.goNamed('profile-edit',
              queryParameters: overrideLocation == null
                  ? {}
                  : {'redirect': overrideLocation});
          return;
        }
      } catch (error) {
        await ConnectionService.showConnectionErrorDialog();
        await FlutterExitApp.exitApp(iosForceExit: true);
        return;
      }
    }

    // if not authenticated, go directly to initialLocation instead of stacking home first
    if (session == null) {
      router.go(initialLocation);
      return;
    }

    // put the home screen in the stack first
    router.go('/');

    // push initial location after the home screen if set
    if (initialLocation != '/') {
      // reset initial location
      _initialLocation = '/';

      // defering this seems to be necessary to ensure the previous route gets loaded
      WidgetsBinding.instance
          .addPostFrameCallback((_) => router.push(initialLocation));
    }
  }
}

final routerProvider = Provider((ref) => RouterService(ref));
