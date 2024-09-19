import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/profile.dart';
import 'package:squadquest/controllers/settings.dart';
import 'package:squadquest/router.dart';

class _MenuItem {
  static const divider = Key('divider');

  final IconData icon;
  final String label;
  final String? route;
  final Future<void> Function(BuildContext context, WidgetRef ref)? handler;
  final bool developerMode;

  _MenuItem({
    required this.icon,
    required this.label,
    this.route,
    this.handler,
    this.developerMode = false,
  })  : assert(route != null || handler != null, 'route or handler required'),
        assert(route == null || handler == null,
            'route and handler are mutually exclusive');
}

final _menu = [
  _MenuItem(
    icon: Icons.home,
    label: 'Explore Events',
    route: 'home',
  ),
  _MenuItem(
    icon: Icons.people,
    label: 'Buddy List',
    route: 'friends',
  ),
  _MenuItem(
    icon: Icons.checklist,
    label: 'Topics',
    route: 'topics',
  ),
  _MenuItem(
    icon: Icons.person,
    label: 'Profile',
    route: 'profile-edit',
  ),
  _MenuItem(
    icon: Icons.settings,
    label: 'Settings',
    route: 'settings',
  ),
  _MenuItem(
    icon: Icons.map,
    label: 'Map',
    route: 'map',
    developerMode: true,
  ),
  _MenuItem.divider,
  _MenuItem(
    icon: Icons.logout,
    label: 'Sign out',
    handler: (context, ref) async {
      final authController = ref.read(authControllerProvider.notifier);

      context.goNamed('login');

      // wait for transition to complete before signing out so that previous screens don't try to update with new state
      await ModalRoute.of(context)!.completed;
      await authController.signOut();
    },
  )
];

final _menuItems = _menu.whereType<_MenuItem>().toList();

bool isDrawerRoute(String routeName) {
  return _menuItems.any((item) => item.route == routeName);
}

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final developerMode = ref.watch(developerModeProvider);
    final effectiveMenuItems = _menuItems
        .where((menuItem) => !menuItem.developerMode || developerMode)
        .toList();

    // get current screen name
    final router = ref.watch(routerProvider);
    final currentScreenName =
        router.routerDelegate.currentConfiguration.last.route.name;

    return NavigationDrawer(
      selectedIndex: effectiveMenuItems
          .indexWhere((item) => item.route == currentScreenName),
      onDestinationSelected: (int newSelection) async {
        final menuItem = effectiveMenuItems[newSelection];

        Navigator.pop(context);

        if (menuItem.handler != null) {
          await menuItem.handler!(context, ref);
        } else if (menuItem.route == 'home') {
          context.goNamed(menuItem.route!);
        } else {
          context.pushNamed(menuItem.route!);
        }
      },
      children: <Widget>[
        profileAsync.when(
            data: (profile) => UserAccountsDrawerHeader(
                accountName: Text(profile!.fullName),
                accountEmail: profile.phone == null
                    ? null
                    : Text(profile.phoneFormatted!),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.tertiaryFixed,
                  backgroundImage: (profile.photo != null)
                      ? NetworkImage(profile.photo.toString())
                      : null,
                  child: Text(
                    profile.displayName[0],
                    style: TextStyle(
                      color:
                          Theme.of(context).colorScheme.onTertiaryFixedVariant,
                    ),
                    textScaler: const TextScaler.linear(2),
                  ),
                )),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink()),
        ..._menu
            .where((menuItem) =>
                menuItem is! _MenuItem ||
                !menuItem.developerMode ||
                developerMode)
            .map((menuItem) => switch (menuItem) {
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
