import 'package:flutter/material.dart';

class HomeTopicsPromptBanner extends StatelessWidget {
  final VoidCallback onTap;

  const HomeTopicsPromptBanner({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.interests,
              size: 48,
              color: Theme.of(context).colorScheme.primary.withAlpha(179),
            ),
            const SizedBox(height: 16),
            Text(
              'Subscribe to Topics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'You haven\'t subscribed to any topics yet!\n\nTap here to head to the Topics screen and subscribe to some to see public events.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurface.withAlpha(179),
                    height: 1.4,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
