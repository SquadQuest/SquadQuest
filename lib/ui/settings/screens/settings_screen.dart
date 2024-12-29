import 'package:flutter/material.dart';
import 'package:squadquest/app_scaffold.dart';

import '../widgets/settings_appearance_section.dart';
import '../widgets/settings_privacy_section.dart';
import '../widgets/settings_notifications_section.dart';
import '../widgets/settings_account_section.dart';
import '../widgets/settings_developer_section.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Settings',
      bodyPadding: const EdgeInsets.all(16),
      body: ListView(
        children: const [
          SettingsAppearanceSection(),
          SettingsPrivacySection(),
          SettingsNotificationsSection(),
          SettingsAccountSection(),
          SettingsDeveloperSection(),
        ],
      ),
    );
  }
}
