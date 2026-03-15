import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_preview/device_preview.dart';

import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/settings.dart';
import 'package:squadquest/storybook/mocks.dart';

import 'app.dart';

void main() {
  runApp(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(MockAuthController.new),
        storybookModeProvider.overrideWith((ref) => true),
      ],
      child: kDebugMode
          ? DevicePreview(
              enabled: !kIsWeb && Platform.isMacOS,
              defaultDevice: Devices.ios.iPhoneSE,
              backgroundColor: Colors.black87,
              builder: (context) => const V2App(),
              tools: const [
                DeviceSection(),
                SystemSection(),
              ],
            )
          : const V2App(),
    ),
  );
}
