import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/models/user.dart';

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
  bool _showNotificationDetails = false;
  ThemeMode _themeMode = ThemeMode.system;

  // Mock notification settings using the NotificationType enum
  final Set<NotificationType> _enabledNotifications = {
    NotificationType.friendRequest,
    NotificationType.eventInvitation,
    NotificationType.eventChange,
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
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Show Details',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _showNotificationDetails,
                  onChanged: (value) {
                    setState(() => _showNotificationDetails = value);
                  },
                ),
              ],
            ),
            children: [
              _buildNotificationTile(
                type: NotificationType.friendRequest,
                title: 'Friend Requests',
                subtitle:
                    'When someone who already knows your phone number requests to be your friend',
                icon: Icons.person_add_outlined,
              ),
              _buildNotificationTile(
                type: NotificationType.eventInvitation,
                title: 'Event Invitations',
                subtitle: 'When a friend invites you to an event',
                icon: Icons.mail_outlined,
              ),
              _buildNotificationTile(
                type: NotificationType.eventChange,
                title: 'Event Changes',
                subtitle:
                    'When an event you\'ve RSVPd to has a key detail changed or is canceled',
                icon: Icons.update_outlined,
              ),
              _buildNotificationTile(
                type: NotificationType.friendsEventPosted,
                title: 'New Friends Event',
                subtitle:
                    'When a new friends-only event is posted by one of your friends to a topic you subscribe to',
                icon: Icons.group_outlined,
              ),
              _buildNotificationTile(
                type: NotificationType.publicEventPosted,
                title: 'New Public Event',
                subtitle:
                    'When a new public event is posted to a topic you subscribe to',
                icon: Icons.event_available_outlined,
              ),
              _buildNotificationTile(
                type: NotificationType.guestRsvp,
                title: 'Guest RSVPs',
                subtitle:
                    'When someone changes their RSVP status to an event you posted',
                icon: Icons.how_to_reg_outlined,
              ),
              _buildNotificationTile(
                type: NotificationType.friendOnTheWay,
                title: 'Friends OMW',
                subtitle:
                    'When a friend is on their way to an event you RSVPd to',
                icon: Icons.directions_run_outlined,
              ),
              _buildNotificationTile(
                type: NotificationType.eventMessage,
                title: 'Event Chat',
                subtitle:
                    'When a message gets posted to chat in an event you RSVPd to',
                icon: Icons.chat_outlined,
              ),
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
    Widget? trailing,
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
              if (trailing != null) ...[
                const Spacer(),
                trailing,
              ],
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

  Widget _buildNotificationTile({
    required NotificationType type,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return _buildSettingTile(
      title: title,
      subtitle: _showNotificationDetails ? subtitle : null,
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.primary,
      ),
      trailing: Switch(
        value: _enabledNotifications.contains(type),
        onChanged: (enabled) {
          setState(() {
            if (enabled) {
              _enabledNotifications.add(type);
            } else {
              _enabledNotifications.remove(type);
            }
          });
        },
      ),
    );
  }
}
