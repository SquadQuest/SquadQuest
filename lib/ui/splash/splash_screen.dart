import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/services/router.dart';
import 'package:squadquest/controllers/profile.dart';
import 'package:squadquest/controllers/app_versions.dart';

import 'package:squadquest/services/supabase.dart';

typedef SplashNextScreenRecord = ({
  String name,
  Map<String, String>? pathParameters
});

final splashCompleteProvider = StateProvider<bool>((_) => false);

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

    try {
      logger.t('_continueLoading: loading profile and app versions...');
      await Future.wait([
        ref.read(profileProvider.future),
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
      await Future.delayed(Duration(milliseconds: _minSplashTime - timeDiff));
    }
    logger.d('_continueLoading.waited');

    // check app version
    try {
      logger.t('_continueLoading: showing update alert...');
      await ref.read(appVersionsProvider.notifier).showUpdateAlertIfAvailable();
    } catch (error, stackTrack) {
      logger.e({'error showing update alert': error}, stackTrace: stackTrack);
    }

    // record splash as complete
    ref.read(splashCompleteProvider.notifier).state = true;

    // route to initial screen
    ref.read(routerProvider).goInitialLocation();
  }

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Scaffold(
        body: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [CircularProgressIndicator()],
          ),
        ),
      ),
    );
  }
}
