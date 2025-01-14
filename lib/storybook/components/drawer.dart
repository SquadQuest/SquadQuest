import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:squadquest/storybook/components/modals/share_modal.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  void _showShareModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ShareModal(),
    );
  }

  void _openDiscord() async {
    final uri = Uri.parse('https://discord.gg/4b3d2zpSWY');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      child: Column(
        children: [
          // Profile Section
          Material(
            elevation: 1,
            child: Container(
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
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primaryContainer,
                  ],
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundImage: const NetworkImage(
                      'https://i.pravatar.cc/300?u=sarah',
                    ),
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .onPrimary
                        .withOpacity(0.2),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sarah Chen',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '(555) 123-4567',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimary
                              .withOpacity(0.8),
                        ),
                  ),
                ],
              ),
            ),
          ),

          // Navigation Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildSection(
                  context,
                  title: 'Events',
                  items: [
                    _DrawerItem(
                      icon: Icons.explore_outlined,
                      selectedIcon: Icons.explore,
                      label: 'Explore Events',
                      route: 'home',
                      isSelected: true,
                    ),
                    _DrawerItem(
                      icon: Icons.add_box_outlined,
                      selectedIcon: Icons.add_box,
                      label: 'Create Event',
                      route: 'create-event',
                    ),
                  ],
                ),
                _buildSection(
                  context,
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
                      label: 'Find Friends',
                      route: 'map',
                    ),
                    _DrawerItem(
                      icon: Icons.share_outlined,
                      selectedIcon: Icons.share,
                      label: 'Share SquadQuest',
                      onTap: () => _showShareModal(context),
                    ),
                  ],
                ),
                _buildSection(
                  context,
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
                _buildSection(
                  context,
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
                _buildSection(
                  context,
                  title: 'Community',
                  items: [
                    _DrawerItem(
                      icon: Icons.discord,
                      selectedIcon: Icons.discord,
                      label: 'Join Discord',
                      onTap: _openDiscord,
                    ),
                  ],
                ),
                const Divider(indent: 28, endIndent: 28),
                _buildSignOutButton(context),
              ],
            ),
          ),

          // Version Info
          _buildVersionInfo(context),
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
          Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(50),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 28),
      onTap: () {
        Navigator.pop(context);
        item.onTap?.call();
        if (item.route != null) {
          // Handle navigation
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
        onTap: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildVersionInfo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        'Version 1.0.0 (100)',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _DrawerItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String? route;
  final VoidCallback? onTap;
  final bool isSelected;

  const _DrawerItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.route,
    this.onTap,
    this.isSelected = false,
  });
}
