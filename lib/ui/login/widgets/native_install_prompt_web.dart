import 'package:web/web.dart' show Device;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class NativeInstallPrompt extends StatelessWidget {
  const NativeInstallPrompt({super.key});

  static const String _iosAppUrl =
      'https://apps.apple.com/us/app/squadquest/id6504465196';
  static const String _androidAppUrl =
      'https://play.google.com/store/apps/details?id=app.squadquest';

  @override
  Widget build(BuildContext context) {
    final userAgent = Device.userAgent.toLowerCase();
    final isIOS = userAgent.contains('iphone') || userAgent.contains('ipad');
    final isAndroid = userAgent.contains('android');

    // Only show on web platform
    if (!isIOS && !isAndroid) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final storeUrl = isIOS ? _iosAppUrl : _androidAppUrl;
    final badgeAsset = isIOS
        ? 'assets/store_badges/apple-dark-on-white.png'
        : 'assets/store_badges/google-dark-on-white.png';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(50),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'SquadQuest works best if you install the app:',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => launchUrl(Uri.parse(storeUrl)),
            child: Image.asset(
              badgeAsset,
            ),
          ),
        ],
      ),
    );
  }
}
