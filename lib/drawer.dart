import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:squadquest/services/router.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/profile.dart';
import 'package:squadquest/controllers/settings.dart';
import 'package:squadquest/controllers/app_versions.dart';

class _DrawerItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String? route;
  final Future<void> Function(BuildContext context, WidgetRef ref)? handler;
  final bool developerMode;
  final bool isSelected;

  const _DrawerItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.route,
    this.handler,
    this.developerMode = false,
    this.isSelected = false,
  })  : assert(route != null || handler != null, 'route or handler required'),
        assert(route == null || handler == null,
            'route and handler are mutually exclusive');
}

class _Section {
  final String title;
  final List<_DrawerItem> items;

  const _Section({
    required this.title,
    required this.items,
  });
}

final _sections = [
  _Section(
    title: 'Events',
    items: [
      _DrawerItem(
        icon: Icons.explore_outlined,
        selectedIcon: Icons.explore,
        label: 'Explore Events',
        route: 'home',
      ),
      _DrawerItem(
        icon: Icons.add_box_outlined,
        selectedIcon: Icons.add_box,
        label: 'Create Event',
        route: 'post-event',
      ),
    ],
  ),
  _Section(
    title: 'Interests',
    items: [
      _DrawerItem(
        icon: Icons.local_activity_outlined,
        selectedIcon: Icons.local_activity,
        label: 'Topics',
        route: 'topics',
      ),
    ],
  ),
  _Section(
    title: 'Social',
    items: [
      _DrawerItem(
        icon: Icons.people_outline,
        selectedIcon: Icons.people,
        label: 'Buddy List',
        route: 'friends',
      ),
      _DrawerItem(
        icon: Icons.map_outlined,
        selectedIcon: Icons.map,
        label: 'Buddy Map',
        route: 'map',
      ),
    ],
  ),
  _Section(
    title: 'Account',
    items: [
      _DrawerItem(
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        label: 'Profile',
        route: 'profile-edit',
      ),
      _DrawerItem(
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        label: 'Settings',
        route: 'settings',
      ),
    ],
  ),
  _Section(
    title: 'Community',
    items: [
      _DrawerItem(
        icon: Icons.discord,
        selectedIcon: Icons.discord,
        label: 'Join Discord',
        handler: (context, ref) async {
          final uri = Uri.parse('https://discord.gg/4b3d2zpSWY');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        },
      ),
    ],
  ),
];

final _allItems = _sections.expand((section) => section.items).toList();

bool isDrawerRoute(String routeName) {
  return _allItems.any((item) => item.route == routeName);
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
    final routerService = ref.watch(routerProvider);
    final currentScreenName = routerService
        .router.routerDelegate.currentConfiguration.last.route.name;

    return Drawer(
      child: Column(
        children: [
          // Profile Section
          Material(
            elevation: 1,
            child: profileAsync.when(
              data: (profile) => Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  24,
                  MediaQuery.of(context).padding.top + 24,
                  24,
                  24,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).colorScheme.surfaceContainer,
                      Theme.of(context).colorScheme.primaryContainer,
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    if (profile?.photo != null)
                      CircleAvatar(
                        radius: 32,
                        backgroundImage:
                            NetworkImage(profile!.photo.toString()),
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .onPrimary
                            .withAlpha(51),
                      ),
                    const SizedBox(height: 12),
                    if (profile != null)
                      Text(
                        profile.fullName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                    if (profile?.phone != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        profile!.phoneFormatted!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          // Navigation Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ..._sections
                    .where((section) => section.items
                        .any((item) => !item.developerMode || developerMode))
                    .map(
                      (section) => _buildSection(
                        context,
                        title: section.title,
                        items: section.items
                            .where(
                                (item) => !item.developerMode || developerMode)
                            .map(
                              (item) => item.copyWith(
                                isSelected: item.route == currentScreenName,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                const Divider(indent: 28, endIndent: 28),
                _buildSignOutButton(context),
              ],
            ),
          ),

          // Version Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: ref.watch(currentAppPackageProvider).when(
                  data: (packageInfo) => Text(
                    'Version ${packageInfo.version} (${packageInfo.buildNumber})',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<_DrawerItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ...items.map((item) => _buildNavigationItem(context, item)),
      ],
    );
  }

  Widget _buildNavigationItem(BuildContext context, _DrawerItem item) {
    return ListTile(
      leading: Icon(
        item.isSelected ? item.selectedIcon : item.icon,
        color: item.isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(
        item.label,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: item.isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
            ),
      ),
      selected: item.isSelected,
      selectedTileColor:
          Theme.of(context).colorScheme.primaryContainer.withAlpha(51),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(50),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 28),
      onTap: () async {
        Navigator.pop(context);

        if (item.handler != null) {
          await item.handler!(context, ref);
        } else if (item.route == 'home') {
          context.goNamed(item.route!);
        } else {
          context.pushNamed(item.route!);
        }
      },
    );
  }

  Widget _buildSignOutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      child: ListTile(
        leading: Icon(
          Icons.logout,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text(
          'Sign Out',
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        onTap: () async {
          await ref.read(authControllerProvider.notifier).signOut();
        },
      ),
    );
  }
}

extension on _DrawerItem {
  _DrawerItem copyWith({
    IconData? icon,
    IconData? selectedIcon,
    String? label,
    String? route,
    Future<void> Function(BuildContext context, WidgetRef ref)? handler,
    bool? developerMode,
    bool? isSelected,
  }) {
    return _DrawerItem(
      icon: icon ?? this.icon,
      selectedIcon: selectedIcon ?? this.selectedIcon,
      label: label ?? this.label,
      route: route ?? this.route,
      handler: handler ?? this.handler,
      developerMode: developerMode ?? this.developerMode,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
