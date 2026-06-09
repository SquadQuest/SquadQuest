import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'models/activity.dart';
import 'providers/auth_controller.dart';
import 'screens/activity/activity_detail_screen.dart';
import 'screens/compose/compose_idea_screen.dart';
import 'screens/login/login_screen.dart';
import 'screens/squads/create_squad_screen.dart';
import 'screens/timeline/timeline_screen.dart';

/// Auth-gated router. Redirects to /login until signed in, to /splash while the
/// persisted session resolves, and to / once signed in.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      if (auth is AuthLoading) return loc == '/splash' ? null : '/splash';
      if (auth is! SignedIn) return loc == '/login' ? null : '/login';
      if (loc == '/login' || loc == '/splash') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const _Splash()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, _) => const TimelineScreen()),
      GoRoute(path: '/ideas/new', builder: (_, _) => const ComposeIdeaScreen()),
      GoRoute(
        path: '/squads/new',
        builder: (_, _) => const CreateSquadScreen(),
      ),
      GoRoute(
        path: '/activity/:id',
        builder: (_, state) =>
            ActivityDetailScreen(activity: state.extra as Activity?),
      ),
    ],
  );
});

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
