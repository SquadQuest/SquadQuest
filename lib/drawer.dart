import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squad_quest/controllers/auth.dart';

final _appDrawerSelectionProvider = StateProvider<int>((ref) {
  return 0;
});

class _MenuItem {
  static const divider = Key('divider');

  final IconData icon;
  final String label;
  final String route;
  final Future<void> Function(WidgetRef ref)? beforeNavigate;

  _MenuItem({
    required this.icon,
    required this.label,
    required this.route,
    this.beforeNavigate,
  });
}

final _menu = [
  _MenuItem(
    icon: Icons.home,
    label: 'Home',
    route: '/',
  ),
  _MenuItem(
    icon: Icons.person,
    label: 'Profile',
    route: '/profile',
  ),
  _MenuItem(
    icon: Icons.settings,
    label: 'Settings',
    route: '/settings',
  ),
  _MenuItem.divider,
  _MenuItem(
    icon: Icons.logout,
    label: 'Sign out',
    route: '/login',
    beforeNavigate: (ref) async {
      await ref.read(authControllerProvider.notifier).signOut();
      ref.read(_appDrawerSelectionProvider.notifier).state = 0;
    },
  ),
];

final _menuItems = _menu.whereType<_MenuItem>().toList();

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  _onDestinationSelected(int newSelection) async {
    final menuItem = _menuItems[newSelection];

    ref.read(_appDrawerSelectionProvider.notifier).state = newSelection;

    if (menuItem.beforeNavigate != null) {
      await menuItem.beforeNavigate!(ref);
    }

    if (context.mounted) {
      context.go(menuItem.route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final appDrawerSelection = ref.watch(_appDrawerSelectionProvider);

    return NavigationDrawer(
      selectedIndex: appDrawerSelection,
      onDestinationSelected: _onDestinationSelected,
      children: <Widget>[
        UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.blue,
            ),
            accountName: Text(
                '${user?.userMetadata!['first_name']} ${user?.userMetadata!['last_name']}'),
            accountEmail: Text('${user?.phone}')),
        ..._menu.map((menuItem) => switch (menuItem) {
              _MenuItem.divider => const Divider(thickness: 1),
              (_MenuItem _) => NavigationDrawerDestination(
                  icon: Icon(menuItem.icon),
                  label: Text(menuItem.label),
                ),
              _ => throw 'Invalid menu item: $menuItem',
            })
      ],
    );
  }
}
