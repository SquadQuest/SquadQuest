import 'package:flutter/material.dart';

class ProfileFormAppearanceSection extends StatelessWidget {
  final Color selectedColor;
  final VoidCallback onColorTap;

  const ProfileFormAppearanceSection({
    super.key,
    required this.selectedColor,
    required this.onColorTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appearance',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Trail Color'),
              subtitle: const Text('Choose the color for your map trail'),
              trailing: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selectedColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: selectedColor.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              onTap: onColorTap,
            ),
          ],
        ),
      ),
    );
  }
}
