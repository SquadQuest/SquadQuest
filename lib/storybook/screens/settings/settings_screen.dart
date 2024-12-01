import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadquest/app_scaffold.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Mock settings state
  bool _locationSharing = false;
  bool _calendarSync = false;
  bool _developerMode = false;
  ThemeMode _themeMode = ThemeMode.system;

  // Mock notification settings
  final Map<String, bool> _notificationSettings = {
    'Event reminders': true,
    'Friend requests': true,
    'Event chat messages': false,
    'Event updates': true,
    'New events from friends': true,
  };

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Settings',
      body: ListView(
        children: [
          _buildSection(
            title: 'Appearance',
            icon: Icons.palette_outlined,
            children: [
              _buildSettingTile(
                title: 'Theme',
                subtitle: 'Customize app appearance',
                leading: Icon(
                  _themeMode == ThemeMode.light
                      ? Icons.light_mode
                      : _themeMode == ThemeMode.dark
                          ? Icons.dark_mode
                          : Icons.brightness_auto,
                  color: Theme.of(context).colorScheme.primary,
                ),
                trailing: DropdownButton<ThemeMode>(
                  value: _themeMode,
                  onChanged: (ThemeMode? value) {
                    if (value != null) {
                      setState(() => _themeMode = value);
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('System default'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Light'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Dark'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _buildSection(
            title: 'Privacy & Integration',
            icon: Icons.security_outlined,
            children: [
              _buildSettingTile(
                title: 'Location Sharing',
                subtitle: 'Share your location during live events',
                leading: Icon(
                  Icons.location_on_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                trailing: Switch(
                  value: _locationSharing,
                  onChanged: (value) {
                    setState(() => _locationSharing = value);
                  },
                ),
              ),
              _buildSettingTile(
                title: 'Calendar Sync',
                subtitle: 'Add events you\'re attending to your calendar',
                leading: Icon(
                  Icons.calendar_month_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                trailing: Switch(
                  value: _calendarSync,
                  onChanged: (value) {
                    setState(() => _calendarSync = value);
                  },
                ),
              ),
            ],
          ),
          _buildSection(
            title: 'Notifications',
            icon: Icons.notifications_outlined,
            children: [
              ..._notificationSettings.entries.map((entry) => _buildSettingTile(
                    title: entry.key,
                    leading: Icon(
                      _getNotificationIcon(entry.key),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    trailing: Switch(
                      value: entry.value,
                      onChanged: (value) {
                        setState(() {
                          _notificationSettings[entry.key] = value;
                        });
                      },
                    ),
                  )),
            ],
          ),
          _buildSection(
            title: 'Account',
            icon: Icons.account_circle_outlined,
            children: [
              _buildSettingTile(
                title: 'Delete Account',
                subtitle: 'Permanently delete your account and data',
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                onTap: () {
                  // Show delete confirmation dialog
                },
              ),
            ],
          ),
          _buildSection(
            title: 'Developer Options',
            icon: Icons.code,
            children: [
              _buildSettingTile(
                title: 'Developer Mode',
                subtitle: 'Enable advanced debugging features',
                leading: Icon(
                  Icons.developer_mode,
                  color: Theme.of(context).colorScheme.primary,
                ),
                trailing: Switch(
                  value: _developerMode,
                  onChanged: (value) {
                    setState(() => _developerMode = value);
                  },
                ),
              ),
              if (_developerMode) ...[
                _buildSettingTile(
                  title: 'App Version',
                  subtitle: '1.0.0 (build 100)',
                  leading: Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                _buildSettingTile(
                  title: 'Clear App Data',
                  subtitle: 'Reset all settings and cached data',
                  leading: Icon(
                    Icons.cleaning_services_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onTap: () {
                    // Show clear data confirmation dialog
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
            ),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingTile({
    required String title,
    String? subtitle,
    required Widget leading,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: SizedBox(
        width: 24,
        height: 24,
        child: leading,
      ),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

  IconData _getNotificationIcon(String setting) {
    switch (setting) {
      case 'Event reminders':
        return Icons.event_available_outlined;
      case 'Friend requests':
        return Icons.person_add_outlined;
      case 'Event chat messages':
        return Icons.chat_outlined;
      case 'Event updates':
        return Icons.update_outlined;
      case 'New events from friends':
        return Icons.group_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }
}
