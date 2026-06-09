# Flutter Project Setup Guide

## Scaffolding Order

Follow this exact sequence when creating a new Flutter project. Commit after each step.

### 1. Tool versions

```bash
asdf set flutter latest
```

### 2. Create Flutter project

```bash
flutter create my_app --empty --platforms ios,android,macos,web --org com.example
```

Then move contents up to the project root:

```bash
mv my_app/.* my_app/* . 2>/dev/null
rmdir my_app
```

Commit with the exact command in the message:

```
feat: initialize Flutter project

Ran: flutter create my_app --empty --platforms ios,android,macos,web --org com.example
Then moved subdirectory contents to root.
```

### 3. Add support tool versions

```bash
asdf set ruby latest
asdf set cocoapods latest
asdf set rust latest  # if native deps need it
```

### 4. VSCode configuration

Create `.vscode/launch.json`:

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "App",
            "type": "dart",
            "request": "launch",
            "program": "lib/main.dart"
        },
        {
            "name": "Storybook",
            "type": "dart",
            "request": "launch",
            "program": "lib/storybook/main.dart"
        },
        {
            "name": "App (profile)",
            "type": "dart",
            "request": "launch",
            "flutterMode": "profile",
            "program": "lib/main.dart"
        },
        {
            "name": "App (release)",
            "type": "dart",
            "request": "launch",
            "flutterMode": "release",
            "program": "lib/main.dart"
        }
    ]
}
```

Create `.vscode/settings.json`:

```json
{
    "dart.flutterSdkPath": "~/.asdf/installs/flutter/3.41.6-stable"
}
```

**Important**: Use `~` for home directory, not `${env:HOME}` — VSCode doesn't interpolate environment variable syntax in settings.

Create `.vscode/extensions.json`:

```json
{
    "recommendations": [
        "Dart-Code.dart-code",
        "Dart-Code.flutter"
    ]
}
```

### 5. Add core dependencies

```bash
flutter pub add flutter_riverpod go_router dio flutter_dotenv flutter_secure_storage
flutter pub add --dev riverpod_lint storybook_toolkit
```

Commit the pubspec.yaml and pubspec.lock changes with the exact commands.

### 6. Add drift (if offline/local DB needed)

```bash
flutter pub add drift drift_flutter sqlite3_flutter_libs path_provider path
flutter pub add --dev build_runner drift_dev
```

Note: `riverpod_lint` and `drift_dev` may have conflicting analyzer version requirements. If so, drop `riverpod_lint` — drift is more essential for offline architecture.

### 7. Create directory structure

```bash
mkdir -p lib/{storybook/screens,models,providers,repositories,database,screens,widgets,constants}
```

### 8. Wire up entrypoints

**lib/main.dart** — real app:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:my_app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const ProviderScope(child: MyApp()));
}
```

**lib/storybook/main.dart** — storybook with mock data:

```dart
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
          name: 'Screens/Example',
          description: 'Example screen.',
          builder: (context) => const Placeholder(),
        ),
      ],
    );
  }
}
```

### 9. Environment config

Create `.env`:

```
API_BASE_URL=http://localhost:3000/api/v1
```

Create `.env.example` with the same content. Add `.env` to `pubspec.yaml` assets:

```yaml
flutter:
  uses-material-design: true
  assets:
    - .env
```

### 10. macOS entitlements

For network requests and keychain access, update both `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`:

```xml
<key>com.apple.security.network.client</key>
<true/>
<key>keychain-access-groups</key>
<array>
    <string>$(AppIdentifierPrefix)com.example.myApp</string>
</array>
```

Then set the development team in Xcode: Runner target → Signing & Capabilities → Team → select for "All" configurations.

### 11. Install Flutter agent skills (optional)

The [flutter/skills](https://github.com/flutter/skills) repo provides official Flutter skills for AI agents. Install selectively:

```bash
npx skills add flutter/skills
```

Select these from the interactive picker:

- `flutter-building-forms`
- `flutter-building-layouts`
- `flutter-theming-apps`
- `flutter-implementing-navigation-and-routing`
- `flutter-handling-http-and-json`
- `flutter-working-with-databases`
- `flutter-caching-data`
- `flutter-testing-apps`
- `flutter-setting-up-on-macos`
- `flutter-improving-accessibility`

**Do NOT install** `flutter-managing-state` or `flutter-architecting-apps` — they prescribe Provider/ChangeNotifier which conflicts with our Riverpod architecture.
