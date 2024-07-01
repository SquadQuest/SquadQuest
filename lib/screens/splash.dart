import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/router.dart';
import 'package:squadquest/drawer.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/profile.dart';
import 'package:squadquest/services/firebase.dart';

typedef SplashNextScreenRecord = ({
  String name,
  Map<String, String>? pathParameters
});
final splashNextScreenProvider =
    StateProvider<SplashNextScreenRecord?>((_) => null);

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  final _minSplashTime = 1000;
  late int _initTime;

  @override
  void initState() {
    super.initState();

    _initTime = DateTime.now().millisecondsSinceEpoch;
  }

  void _afterMinSplashTime(Function() callback) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final timeDiff = now - _initTime;

    Future.delayed(
        timeDiff < _minSplashTime
            ? Duration(milliseconds: timeDiff)
            : Duration.zero,
        callback);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);
    final profile = ref.watch(profileProvider);

    log('SplashScreen.build: session: ${session == null ? 'no' : 'yes'}, profile: $profile');
    if (profile.hasValue) {
      _afterMinSplashTime(() async {
        await ref.read(firebaseMessagingServiceProvider).requestPermissions();

        final router = ref.read(routerProvider);
        final splashNextScreen = ref.read(splashNextScreenProvider);

        logger.t({
          'after splash min time': {
            'last-route-name':
                router.routerDelegate.currentConfiguration.last.route.name,
            'splash-next-screen': splashNextScreen
          }
        });

        if (router.routerDelegate.currentConfiguration.last.route.name !=
            'splash') {
          logger.t('skipping splash nav because current route is not splash');
          return;
        }

        if (context.mounted) {
          // send user to login screen if not authenticated
          if (session == null) {
            context.goNamed('login');
            return;
          }

          // send user to profile screen if profile is not set
          if (profile.value == null) {
            context.goNamed('profile-edit');
            return;
          }

          // go to the home screen if no splashNextScreen has been set
          if (splashNextScreen == null) {
            context.goNamed('home');
            return;
          }

          // if splashNextScreen is in the drawer navigation, go directly to it replacing the splash screen
          if (isDrawerRoute(splashNextScreen.name)) {
            logger.t('replacing splash screen with drawer nav screen');
            context.goNamed(splashNextScreen.name,
                pathParameters: splashNextScreen.pathParameters ?? {});
            return;
          }

          // put the home screen in the stack first
          logger.t('pushing home screen before splashNextScreen');
          context.goNamed('home');

          // push the queued splashNextScreen after the home screen
          context.pushNamed(splashNextScreen.name,
              pathParameters: splashNextScreen.pathParameters ?? {});
        }
      });
    }

    return const SafeArea(
      child: Scaffold(
        body: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
