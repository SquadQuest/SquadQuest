import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:test_screen/test_screen.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  initializeDateFormatting();

  initializeDefaultTestScreenConfig(TestScreenConfig(
      locales: [
        'en'
      ],
      devices: {
        UITargetPlatform.webAndroid: [TestScreenDevice.forWeb(412, 915)],
        UITargetPlatform.webIos: [TestScreenDevice.forWeb(393, 852)],
        UITargetPlatform.android: [
          const TestScreenDevice(
            id: 'Pixel2',
            manufacturer: 'Google',
            name: 'Pixel 2',
            size: Size(1080, 1920),
            devicePixelRatio: 2.625,
          ),
          const TestScreenDevice(
            id: 'Pixel8Pro',
            manufacturer: 'Google',
            name: 'Pixel 8 Pros',
            size: Size(1344, 2992),
            devicePixelRatio: 3.0,
          ),
        ],
        UITargetPlatform.iOS: [
          const TestScreenDevice(
            id: 'iPhoneSE',
            manufacturer: 'Apple',
            name: 'iPhone SE 2022',
            size: Size(750, 1334),
            devicePixelRatio: 2.0,
          ),
          const TestScreenDevice(
            id: 'iPhone15Plus',
            manufacturer: 'Apple',
            name: 'iPhone 15 Plus',
            size: Size(1290, 2796),
            devicePixelRatio: 3.0,
          ),
        ],
      },
      onAfterCreate: (WidgetTester tester, Widget screen) async {
        await tester.pumpAndSettle();
      }));

  return testMain();
}
