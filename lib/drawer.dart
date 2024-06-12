import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squad_quest/controllers/auth.dart';

final _appDrawerSelectionProvider = StateProvider<int>((ref) {
  return 0;
});

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final appDrawerSelection = ref.watch(_appDrawerSelectionProvider);

    return NavigationDrawer(
      selectedIndex: appDrawerSelection,
      onDestinationSelected: (newSelection) async {
        switch (newSelection) {
          case 0:
            context.go('/');
            break;
          case 1:
            context.go('/settings');
            break;
          case 2:
            newSelection = 0;
            await ref.read(authControllerProvider.notifier).signOut();
            if (context.mounted) {
              context.go('/login');
            }
            break;
        }

        ref.read(_appDrawerSelectionProvider.notifier).state = newSelection;
      },
      children: <Widget>[
        UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.blue,
            ),
            accountName: Text(
                '${user?.userMetadata!['first_name']} ${user?.userMetadata!['last_name']}'),
            accountEmail: Text('${user?.phone}')),
        const NavigationDrawerDestination(
          icon: Icon(Icons.home),
          selectedIcon: Icon(Icons.home_filled),
          label: Text('Home'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.settings),
          label: Text('Settings'),
        ),
        const Divider(
          thickness: 1,
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.logout),
          label: Text('Sign out'),
        ),
      ],
    );
  }
}
