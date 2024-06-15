import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squadquest/common.dart';
import 'package:squadquest/controllers/auth.dart';

class _MenuItem {
  static const divider = Key('divider');

  final IconData icon;
  final String label;
  final String route;
  final Future<void> Function(WidgetRef ref)? afterNavigate;

  _MenuItem({
    required this.icon,
    required this.label,
    required this.route,
    this.afterNavigate,
  });
}

final _menu = [
  _MenuItem(
    icon: Icons.home,
    label: 'Home',
    route: '/',
  ),
  _MenuItem(
    icon: Icons.people,
    label: 'Buddy List',
    route: '/friends',
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
    afterNavigate: (ref) async {
      await ref.read(authControllerProvider.notifier).signOut();
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
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);

    return NavigationDrawer(
      selectedIndex: null,
      onDestinationSelected: (int newSelection) async {
        final menuItem = _menuItems[newSelection];

        Navigator.pop(context);

        context.go(menuItem.route);

        if (menuItem.afterNavigate != null) {
          await menuItem.afterNavigate!(ref);
        }
      },
      children: <Widget>[
        if (session != null)
          UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.blue,
              ),
              accountName: Text(
                  '${session.user.userMetadata!['first_name']} ${session.user.userMetadata!['last_name']}'),
              accountEmail: Text(formatPhone(session.user.phone!))),
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
