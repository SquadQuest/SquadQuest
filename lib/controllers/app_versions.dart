import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:squadquest/router.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/controllers/settings.dart';
import 'package:squadquest/models/app_version.dart';

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
    final supabase = ref.read(supabaseClientProvider);
    final packageInfo = await ref.read(currentAppPackageProvider.future);

    final data = await supabase
        .from('app_versions')
        .select()
        .gte('build', packageInfo.buildNumber)
        .order('build', ascending: false);

    final appVersions = await hydrate(data);

    return appVersions;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(fetch);
  }

  Future<List<AppVersion>> hydrate(List<Map<String, dynamic>> data) async {
    return data.map(AppVersion.fromMap).toList();
  }

  Future<bool> isUpdateAvailable() async {
    // wait for versions to be loaded
    await future;

    // get current version
    final packageInfo = await ref.read(currentAppPackageProvider.future);

    return state.value!.first.build > int.parse(packageInfo.buildNumber);
  }

  Future<void> showUpdateAlertIfAvailable() async {
    // check if user has already dismissed this update
    final latestBuild = state.value!.first.build;
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getInt('updateAppBuildDismissed') == latestBuild) {
      return;
    }

    // dismiss if no update is available
    if (!await isUpdateAvailable()) {
      return;
    }

    // show update dialog
    final result = await showDialog<bool>(
      context: navigatorKey.currentContext!,
      barrierDismissible: false,
      builder: await _buildDialog(),
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
  }

  Future<Widget Function(BuildContext)> _buildDialog() async {
    final packageInfo = await ref.read(currentAppPackageProvider.future);
    final currentBuild = int.parse(packageInfo.buildNumber);
    final versionsWithNotices = state.value!
        .where((version) =>
            version.build != currentBuild && version.notices != null)
        .toList();
    final versionsWithNews = state.value!
        .where(
            (version) => version.build != currentBuild && version.news != null)
        .toList();

    return (BuildContext context) => AlertDialog(
          title: const Text('New version available'),
          scrollable: true,
          content: Column(
            children: [
              Text(
                  'You currently have v$currentBuild installed and v${state.value!.first.version} is available.',
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
            TextButton(
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: const Text('Update'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
  }
}
