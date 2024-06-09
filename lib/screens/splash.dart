import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squad_quest/controllers/auth.dart';
import 'package:squad_quest/screens/home.dart';
import 'package:squad_quest/screens/login.dart';

class SplashView extends ConsumerStatefulWidget {
  const SplashView({super.key});

  static const routeName = '/splash';

  @override
  ConsumerState<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends ConsumerState<SplashView> {
  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(seconds: 1), () {
      final authProvider = ref.read(authControllerProvider);

      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => authProvider.value == null
                ? const LoginView()
                : const HomeView(),
          ),
          (_) => false);
    });
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
