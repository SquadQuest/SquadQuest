import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/services/initialization.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/ui/login/login_screen.dart';

class AppStartupWidget extends ConsumerWidget {
  const AppStartupWidget({
    super.key,
    required this.onLoaded,
  });

  final WidgetBuilder onLoaded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initState = ref.watch(initializationProvider);

    return initState.when(
      loading: () => const SafeArea(
        child: Scaffold(
          body: Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [CircularProgressIndicator()],
            ),
          ),
        ),
      ),
      error: (error, stack) => SafeArea(
        child: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'An error occurred while starting the app',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(initializationProvider),
                    child: Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      data: (_) {
        final authState = ref.watch(authControllerProvider);

        if (authState == null) {
          return const LoginScreen();
        }

        return onLoaded(context);
      },
    );
  }
}
