import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squad_quest/screens/splash.dart';
import 'package:squad_quest/screens/login.dart';
import 'package:squad_quest/screens/verify.dart';
import 'package:squad_quest/screens/initialize_profile.dart';
import 'package:squad_quest/screens/home.dart';
import 'package:squad_quest/screens/settings.dart';
import 'package:squad_quest/screens/post_event.dart';

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
        name: 'initialize-profile',
        path: '/initialize-profile',
        builder: (context, state) => const InitializeProfileScreen(),
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
    ],
  );
});
