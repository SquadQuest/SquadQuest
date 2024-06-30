import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/screens/splash.dart';
import 'package:squadquest/screens/login.dart';
import 'package:squadquest/screens/verify.dart';
import 'package:squadquest/screens/profile_form.dart';
import 'package:squadquest/screens/home.dart';
import 'package:squadquest/screens/settings.dart';
import 'package:squadquest/screens/event_form.dart';
import 'package:squadquest/screens/event_details.dart';
import 'package:squadquest/screens/friends.dart';
import 'package:squadquest/screens/map.dart';
import 'package:squadquest/screens/topics.dart';

final navigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider((ref) {
  return GoRouter(
    initialLocation: '/splash',
    navigatorKey: navigatorKey,
    redirect: (BuildContext context, GoRouterState state) {
      final session = ref.read(authControllerProvider);
      if (session == null &&
          state.topRoute?.name != 'login' &&
          state.topRoute?.name != 'verify' &&
          state.topRoute?.name != 'splash') {
        return state.namedLocation('login', queryParameters: {
          'redirect': state.uri.toString(),
        });
      } else {
        return null;
      }
    },
    routes: [
      GoRoute(
        name:
            'splash', // Optional, add name to your routes. Allows you navigate by name instead of path
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
        builder: (context, state) => const EventEditScreen(),
      ),
      GoRoute(
        name: 'event-details',
        path: '/events/:id',
        builder: (context, GoRouterState state) =>
            EventDetailsScreen(instanceId: state.pathParameters['id']!),
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
});
