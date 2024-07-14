import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:squadquest/common.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:squadquest/router.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/controllers/settings.dart';
import 'package:squadquest/models/app_version.dart';

enum _AppUpdateDialogType { update, changes }

final currentAppPackageProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

final appVersionsProvider =
    AsyncNotifierProvider<AppVersionsController, List<AppVersion>>(
        AppVersionsController.new);

class AppVersionsController extends AsyncNotifier<List<AppVersion>> {
  @override
  Future<List<AppVersion>> build() async {
    return fetch();
  }

  Future<List<AppVersion>> fetch() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final appUpdatedChangesDismissed =
        prefs.getInt('appUpdatedChangesDismissed') ?? 1;

    final supabase = ref.read(supabaseClientProvider);
    final data = await supabase
        .from('app_versions')
        .select()
        .gte('build', appUpdatedChangesDismissed)
        .order('build', ascending: false);

    return await hydrate(data);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(fetch);
  }

  Future<List<AppVersion>> hydrate(List<Map<String, dynamic>> data) async {
    return data.map(AppVersion.fromMap).toList();
  }

  Future<void> showUpdateAlertIfAvailable() async {
    final packageInfo = await ref.read(currentAppPackageProvider.future);
    final currentBuild = int.parse(packageInfo.buildNumber);
    final AppVersionChannel? currentChannel = switch (packageInfo) {
      PackageInfo(installerStore: 'com.apple.testflight') =>
        AppVersionChannel.testflight,
      PackageInfo(installerStore: 'com.android.shell') ||
      PackageInfo(installerStore: 'com.google.android.apps.nbu.files') ||
      PackageInfo(installerStore: 'com.google.android.packageinstaller') =>
        AppVersionChannel.githubAPK,
      _ when kIsWeb => AppVersionChannel.web,
      _ when Platform.isAndroid => AppVersionChannel.android,
      _ when Platform.isIOS => AppVersionChannel.ios,
      _ => null
    };

    // skip for development builds
    if (currentBuild == 1) {
      return;
    }

    final appVersions = await future;

    // skip if no version data available
    if (appVersions.isEmpty) {
      return;
    }

    final latestBuild = appVersions
        .firstWhereOrNull(
            (version) => version.availability.contains(currentChannel))
        ?.build;

    final prefs = ref.read(sharedPreferencesProvider);
    final updateAppBuildDismissed = prefs.getInt('updateAppBuildDismissed');
    final appUpdatedChangesDismissed =
        prefs.getInt('appUpdatedChangesDismissed') ?? 1;

    // show update dialog if current version isn't the newest
    if (latestBuild != null &&
        latestBuild != updateAppBuildDismissed &&
        currentBuild < latestBuild) {
      // show update dialog
      final result = await showDialog<bool>(
        context: navigatorKey.currentContext!,
        barrierDismissible: false,
        builder: await _buildDialog(
            fromBuild: currentBuild,
            toBuild: latestBuild,
            type: _AppUpdateDialogType.update),
      );

      // dismiss if user dismissed
      if (result == null) {
        prefs.setInt('updateAppBuildDismissed', latestBuild);
        return;
      }

      // launch update URL
      if (kIsWeb) {
        launchUrl(Uri.parse('javascript:location.reload()'));
      } else if (Platform.isIOS) {
        launchUrl(
            Uri.parse('https://apps.apple.com/us/app/squadquest/id6504465196'));
      } else if (Platform.isAndroid) {
        launchUrl(Uri.parse(
            'https://play.google.com/store/apps/details?id=app.squadquest'));
      }
      return;
    }

    // show changes dialog when a new version launches for the first time
    if (appUpdatedChangesDismissed < currentBuild) {
      // show changes dialog
      await showDialog<bool>(
        context: navigatorKey.currentContext!,
        barrierDismissible: false,
        builder: await _buildDialog(
            fromBuild: appUpdatedChangesDismissed,
            toBuild: currentBuild,
            type: _AppUpdateDialogType.changes),
      );

      prefs.setInt('appUpdatedChangesDismissed', currentBuild);
    }
  }

  Future<Widget Function(BuildContext)> _buildDialog(
      {required int fromBuild,
      required int toBuild,
      required _AppUpdateDialogType type}) async {
    final appVersions = await future;

    final fromVersion = appVersions
        .firstWhere((version) => version.build == fromBuild,
            orElse: () => appVersions.last)
        .version;
    final toVersion = appVersions
        .firstWhere((version) => version.build == toBuild,
            orElse: () => appVersions.first)
        .version;

    final versionsWithNotices = appVersions.where((version) {
      if (version.notices == null) return false;
      if (version.build > toBuild) return false;
      return version.build > fromBuild;
    }).toList();

    final versionsWithNews = appVersions.where((version) {
      if (version.news == null) return false;
      if (version.build > toBuild) return false;
      return version.build > fromBuild;
    }).toList();

    return (BuildContext context) => AlertDialog(
          title: Text(switch (type) {
            _AppUpdateDialogType.update => 'New version available',
            _AppUpdateDialogType.changes => 'Welcome to v$toVersion'
          }),
          scrollable: true,
          content: Column(
            children: [
              Text(
                  switch (type) {
                    _AppUpdateDialogType.update =>
                      'You currently have v$fromVersion installed and v$toVersion is available',
                    _AppUpdateDialogType.changes =>
                      'You have just updated from v$fromVersion to v$toVersion'
                  },
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              ...versionsWithNotices.map((version) => ListTile(
                    trailing: const Icon(Icons.warning),
                    title: Text('Notice for v${version.version}'),
                    subtitle: Text(version.notices!),
                  )),
              ...versionsWithNews.map((version) => ListTile(
                    title: Text('New in v${version.version}'),
                    subtitle: Text(version.news!),
                  )),
            ],
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: const Text('Dismiss'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            if (type == _AppUpdateDialogType.update) ...[
              TextButton(
                style: TextButton.styleFrom(
                  textStyle: Theme.of(context).textTheme.labelLarge,
                ),
                child: const Text('Update'),
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
              ),
            ]
          ],
        );
  }
}
