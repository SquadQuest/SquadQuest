import 'package:flutter/material.dart';

class NativeInstallPrompt extends StatelessWidget {
  const NativeInstallPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    // Only shown on web - return empty widget on native platforms
    return const SizedBox.shrink();
  }
}
