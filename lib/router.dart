import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squad_quest/screens/splash.dart';
import 'package:squad_quest/screens/login.dart';
import 'package:squad_quest/screens/verify.dart';
import 'package:squad_quest/screens/profile.dart';
import 'package:squad_quest/screens/home.dart';
import 'package:squad_quest/screens/settings.dart';
import 'package:squad_quest/screens/post_event.dart';
import 'package:squad_quest/screens/event_details.dart';
import 'package:squad_quest/screens/friends.dart';

final navigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider((ref) {
  return GoRouter(
    initialLocation: '/splash',
    navigatorKey: navigatorKey,
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
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        name: 'verify',
        path: '/verify',
        builder: (context, state) => const VerifyScreen(),
      ),
      GoRoute(
        name: 'profile',
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
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
        builder: (context, state) => const PostEventScreen(),
      ),
      GoRoute(
        name: 'event-details',
        path: '/events/:id',
        builder: (context, GoRouterState state) =>
            EventDetailsScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        name: 'friends',
        path: '/friends',
        builder: (context, state) => const FriendsScreen(),
      ),
    ],
  );
});
