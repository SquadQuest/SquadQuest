import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/profile.dart';
import 'package:squadquest/services/firebase.dart';

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

        if (context.mounted) {
          context.go(session == null
              ? '/login'
              : profile.value == null
                  ? '/profile'
                  : '/');
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
