import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'models/activity.dart';
import 'models/message.dart';
import 'providers/auth_controller.dart';
import 'screens/activity/activity_detail_screen.dart';
import 'screens/compose/compose_idea_screen.dart';
import 'screens/communities/discover_screen.dart';
import 'screens/friends/friends_screen.dart';
import 'screens/login/login_screen.dart';
import 'screens/squads/create_squad_screen.dart';
import 'screens/thread/thread_screen.dart';
import 'screens/timeline/timeline_screen.dart';
import 'screens/welcome/welcome_screen.dart';

/// Auth-gated router. Redirects to /login until signed in, to /splash while the
/// persisted session resolves, to /welcome when a signed-in user still needs
/// onboarding (null first_name), and to / once signed in + named.
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
      // Onboarding gate: a freshly-claimed/created profile has no name yet.
      final needsName = auth.profile.firstName?.isEmpty ?? true;
      if (needsName) return loc == '/welcome' ? null : '/welcome';
      if (loc == '/login' || loc == '/splash' || loc == '/welcome') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const _Splash()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/', builder: (_, _) => const TimelineScreen()),
      GoRoute(path: '/friends', builder: (_, _) => const FriendsScreen()),
      GoRoute(
        path: '/ideas/new',
        builder: (_, state) =>
            ComposeIdeaScreen(broughtEvent: state.extra as EventRef?),
      ),
      GoRoute(
        path: '/squads/new',
        builder: (_, _) => const CreateSquadScreen(),
      ),
      GoRoute(
        path: '/communities',
        builder: (_, _) => const DiscoverCommunitiesScreen(),
      ),
      GoRoute(
        path: '/activity/:id',
        builder: (_, state) =>
            ActivityDetailScreen(activity: state.extra as Activity?),
      ),
      GoRoute(
        path: '/thread/:targetType/:targetId',
        builder: (_, state) => ThreadScreen(
          targetType: state.pathParameters['targetType']!,
          targetId: state.pathParameters['targetId']!,
          root: state.extra as Message?,
        ),
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
