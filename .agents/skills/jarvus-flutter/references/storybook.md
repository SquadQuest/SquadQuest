# Storybook Development

## Dual Entrypoint Pattern

The app has two entrypoints:

- `lib/main.dart` — real app, connects to API and drift DB
- `lib/storybook/main.dart` — storybook with mock data, no server needed

The storybook entrypoint wraps screens in a `ProviderScope` with overrides that replace real repositories with fakes.

## Setting Up Storybook

```dart
// lib/storybook/main.dart
// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storybook_toolkit/storybook_toolkit.dart';

void main() {
  runApp(const ProviderScope(child: StorybookApp()));
}

class StorybookApp extends StatelessWidget {
  const StorybookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Storybook(
      plugins: StorybookPlugins(
        initialDeviceFrameData: DeviceFrameData(
          device: Devices.ios.iPhone13,
          orientation: Orientation.portrait,
        ),
      ),
      stories: [
        Story(
          name: 'Screens/Login',
          description: 'Login screen.',
          builder: (context) => const LoginScreen(),
        ),
      ],
    );
  }
}
```

The `// ignore_for_file: depend_on_referenced_packages` is needed because `storybook_toolkit` is a dev dependency but imported from `lib/`.

## Story Organization

Use forward-slash naming for categories:

```dart
Story(name: 'Screens/Login', ...)
Story(name: 'Screens/Station Overview', ...)
Story(name: 'Forms/Pathway Form / Walkway', ...)
Story(name: 'Forms/Pathway Form / Stairs', ...)
```

## Mock Data

Create a mock data file with realistic test data:

```dart
// lib/storybook/mock_data.dart
class MockData {
  static final station = Station(
    id: 's-001',
    name: 'Test Station',
    downloadedAt: DateTime(2026, 3, 31),
  );

  static const levels = [
    Level(id: 'l-1', levelId: 'B1', levelIndex: -1.0, levelName: 'Busway'),
    Level(id: 'l-2', levelId: 'L1', levelIndex: 0.0, levelName: 'Mezzanine'),
  ];
  // ...
}
```

## Multiple Story Variants

Show the same screen in different states:

```dart
Story(
  name: 'Overview/Fresh download',
  description: 'Zero completion.',
  builder: (context) => StationOverviewScreen(
    station: MockData.station,
    levels: MockData.levels,
    levelStats: {'B1': (completed: 0, total: 8)},
  ),
),
Story(
  name: 'Overview/In progress',
  description: 'Partial completion.',
  builder: (context) => StationOverviewScreen(
    station: MockData.stationWithChanges,
    levels: MockData.levels,
    levelStats: {'B1': (completed: 3, total: 8)},
  ),
),
```

## Storybook with Provider Overrides

When screens depend on providers, override with fakes in the storybook's ProviderScope:

```dart
ProviderScope(
  overrides: [
    stationRepositoryProvider.overrideWithValue(
      FakeStationRepository(stations: MockData.stations),
    ),
    authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
  ],
  child: StorybookApp(),
)
```

## Running Storybook

```bash
# macOS
flutter run -d macos -t lib/storybook/main.dart

# Web (accessible from phone via network)
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 -t lib/storybook/main.dart

# Chrome
flutter run -d chrome -t lib/storybook/main.dart
```

Storybook on web works even when the main app has native dependencies (like drift FFI) because the storybook entrypoint doesn't import the database code.
