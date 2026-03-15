import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      child: const V2App(),
    ),
  );
}
