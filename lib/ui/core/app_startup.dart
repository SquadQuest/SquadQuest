import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/services/initialization.dart';
import 'package:squadquest/services/preferences.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/profile.dart';
import 'package:squadquest/ui/login/login_screen.dart';
import 'package:squadquest/ui/profile_form/profile_form_screen.dart';

class AppStartupWidget extends ConsumerWidget {
  const AppStartupWidget({
    super.key,
    required this.onLoaded,
  });

  final WidgetBuilder onLoaded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initState = ref.watch(appInitializationProvider);

    return initState.when(
      loading: () => _LoadingScreen(),
      error: (error, stack) => _ErrorScreen(
          error: error,
          onRetry: () => ref.invalidate(appInitializationProvider)),
      data: (data) {
        // Show login flow if no auth state
        final authState = ref.watch(authControllerProvider);

        if (authState == null) {
          return const LoginScreen();
        }

        // Show create profile form if no profile
        final profile = ref.watch(profileProvider);

        if (profile.isLoading) {
          return _LoadingScreen();
        } else if (profile.value == null) {
          return ProfileFormScreen();
        }

        return onLoaded(context);
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
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

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'An error occurred while starting the app:\n\n$error',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onRetry,
                  child: Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
