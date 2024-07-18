import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/router.dart';
import 'package:squadquest/drawer.dart';
import 'package:squadquest/services/firebase.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/profile.dart';
import 'package:squadquest/controllers/app_versions.dart';
import 'package:squadquest/models/user.dart';

import 'package:squadquest/services/supabase.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _continueLoading());
  }

  void _continueLoading() async {
    // wait for initial auth state
    await supabaseInitialized;
    logger.d('_continueLoading.supabaseInitialized');

    // load all data needed to bootstrap to load in parallel
    late final UserProfile? profile;

    try {
      logger.t('_continueLoading: loading profile and app versions...');
      await Future.wait([
        ref.read(profileProvider.future).then((result) => profile = result),
        ref.read(appVersionsProvider.future)
      ]);
    } catch (error, stackTrace) {
      logger.e({'error bootstrapping': error}, stackTrace: stackTrace);
    }

    logger.t('ready to continue');

    // ensure splash screen remains visible for at least _minSplashTime
    final now = DateTime.now().millisecondsSinceEpoch;
    final timeDiff = now - _initTime;

    if (timeDiff < _minSplashTime) {
      await Future.delayed(Duration(milliseconds: timeDiff));
    }
    logger.d('_continueLoading.waited');

    // check app version
    try {
      logger.t('_continueLoading: showing update alert...');
      await ref.read(appVersionsProvider.notifier).showUpdateAlertIfAvailable();
    } catch (error, stackTrack) {
      logger.e({'error showing update alert': error}, stackTrace: stackTrack);
    }

    // request permissions
    try {
      logger.t('_continueLoading: requesting permissions...');
      await ref.read(firebaseMessagingServiceProvider).requestPermissions();
    } catch (error, stackTrace) {
      logger.e({'error requesting permissions': error}, stackTrace: stackTrace);
    }

    // route to initial screen
    final router = ref.read(routerProvider);
    final splashNextScreen = ref.read(splashNextScreenProvider);

    logger.t({
      'routing to initial screen': {
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

    // send user to login screen if not authenticated
    final session = ref.read(authControllerProvider);
    if (session == null) {
      router.goNamed('login');
      return;
    }

    // send user to profile screen if profile is not set
    if (profile == null) {
      router.goNamed('profile-edit');
      return;
    }

    // go to the home screen if no splashNextScreen has been set
    if (splashNextScreen == null) {
      router.goNamed('home');
      return;
    }

    // if splashNextScreen is in the drawer navigation, go directly to it replacing the splash screen
    if (isDrawerRoute(splashNextScreen.name)) {
      logger.t('replacing splash screen with drawer nav screen');
      router.goNamed(splashNextScreen.name,
          pathParameters: splashNextScreen.pathParameters ?? {});
      return;
    }

    // put the home screen in the stack first
    logger.t('pushing home screen before splashNextScreen');
    router.goNamed('home');

    // push the queued splashNextScreen after the home screen
    router.pushNamed(splashNextScreen.name,
        pathParameters: splashNextScreen.pathParameters ?? {});
  }

  @override
  Widget build(BuildContext context) {
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
