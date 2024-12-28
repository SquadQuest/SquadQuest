import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_preview/device_preview.dart';

import 'package:squadquest/app.dart';
import 'package:squadquest/services/supabase.dart';

import 'mocks.dart';

void main() {
  mockSupabaseInitializedComplete();

  runApp(buildMockEnvironment(
    DevicePreview(
      enabled: !kIsWeb && Platform.isMacOS,
      defaultDevice: Devices.ios.iPhoneSE,
      backgroundColor: Colors.black87,
      builder: (context) => MyApp(),
      tools: const [
        DeviceSection(),
        SystemSection(),
      ],
    ),
    // scenario: 'no-subscriptions',
  ));
}
