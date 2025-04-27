import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:squadquest/controllers/instances.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/services/initialization.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/profile.dart';
import 'package:squadquest/services/router.dart';
import 'package:squadquest/ui/event/event_screen.dart';
import 'package:squadquest/ui/login/login_screen.dart';
import 'package:squadquest/ui/profile_form/profile_form_screen.dart';

class AppStartupWidget extends ConsumerWidget {
  const AppStartupWidget({
    super.key,
    required this.appRoot,
  });

  final dynamic appRoot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initState = ref.watch(appInitializationProvider);

    return initState.when(
      loading: () => _LoadingScreen(),
      error: (error, stack) {
        logger.e('Error while initializing app',
            error: error, stackTrace: stack);
        return _ErrorScreen(
            error: error,
            onRetry: () => ref.invalidate(appInitializationProvider));
      },
      data: (_) {
        final authState = ref.watch(authControllerProvider);

        // Show login flow if no auth state
        if (authState == null) {
          final authRequested = ref.watch(authRequestedProvider);

          // load event if not logged in and show if it's public, unless auth has been requested
          if (!authRequested) {
            final routePathSegments =
                appRoot.routeInformationProvider.value.uri.pathSegments;

            if (routePathSegments.length == 2 &&
                routePathSegments[0] == 'events') {
              final event =
                  ref.watch(eventDetailsProvider(routePathSegments[1]));

              if (event.isLoading) {
                return _LoadingScreen();
              } else if (event.hasError) {
                return _EventErrorScreen(onHome: () {
                  final router = ref.read(routerProvider);
                  router.router.goNamed('home');

                  ref.read(authRequestedProvider.notifier).state = true;
                });
              }

              if (event.value!.visibility == InstanceVisibility.public) {
                return wrapWithOverlay(EventScreen(eventId: event.value!.id!));
              }
            }
          }

          return const LoginScreen();
        }

        // Show create profile form if no profile
        final profile = ref.watch(profileProvider);

        if (profile.isLoading) {
          return _LoadingScreen();
        } else if (profile.value == null) {
          return wrapWithOverlay(ProfileFormScreen());
        }

        return appRoot;
      },
    );
  }

  Widget wrapWithOverlay(Widget child) {
    return Navigator(pages: [
      MaterialPage(
        child: child,
      )
    ]);
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

class _EventErrorScreen extends StatelessWidget {
  const _EventErrorScreen({
    required this.onHome,
  });

  final VoidCallback onHome;

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
                  'The event you\'re attempting to view is not available',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                // if (navigatorKey.currentContext != null) ...[
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onHome,
                  child: Text('Go to home screen'),
                ),
              ],
              // ],
            ),
          ),
        ),
      ),
    );
  }
}
