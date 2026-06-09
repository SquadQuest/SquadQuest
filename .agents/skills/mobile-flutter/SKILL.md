---
name: mobile-flutter
description: Mobile app development using Flutter + Riverpod + go_router. Use when creating Flutter apps, adding screens, managing state with Riverpod, implementing routing, building offline-first features, or setting up storybook component development. Also use when the user mentions Flutter, Dart, mobile apps, or cross-platform development.
---

# Mobile Flutter Stack

Cross-platform mobile app stack:

- **Flutter** - UI framework (iOS, Android, macOS, Web)
- **Riverpod** - State management (not Provider/ChangeNotifier)
- **go_router** - Declarative routing with deep linking
- **dio** - HTTP client with interceptors
- **storybook_toolkit** - Component development with device frames

No code generation. Models use hand-written `fromJson`/`toJson`.

### Optional: drift (local SQLite)

For offline-first apps that need a local relational database, add **drift**. This is the one exception to the no-codegen rule — drift generates typed query code from table definitions. See [offline-first.md](references/offline-first.md) for setup and patterns.

## Environment Setup

Use [asdf](https://asdf-vm.com/) to manage Flutter and all tool versions:

```bash
# Install Flutter plugin (one-time)
asdf plugin add flutter

# Set project Flutter version
asdf set flutter latest

# Also set support tools as needed
asdf set ruby latest
asdf set cocoapods latest
asdf set rust latest  # needed by some native deps
```

This creates a `.tool-versions` file in the project root. Never use the official Flutter installer, mise, or other version managers.

## Reference Files

| File | When to Use |
|------|-------------|
| [setup-guide.md](references/setup-guide.md) | Starting a new Flutter project from scratch |
| [patterns.md](references/patterns.md) | Riverpod providers, repositories, screen architecture |
| [offline-first.md](references/offline-first.md) | Adding drift for local SQLite, offline download/collect/sync |
| [storybook.md](references/storybook.md) | Setting up storybook, adding stories, mock data |
| [gotchas.md](references/gotchas.md) | Common mistakes and platform-specific issues |

## Quick Reference

### Commands

```bash
# Install dependencies
flutter pub get

# Run on macOS (local dev)
flutter run -d macos

# Run storybook
flutter run -d macos -t lib/storybook/main.dart

# Run on web
flutter run -d chrome

# Analyze
flutter analyze lib/
```

### Package Management

**Always use CLI commands** — never edit `pubspec.yaml` directly:

```bash
# Add runtime dependency
flutter pub add <package>

# Add dev dependency
flutter pub add --dev <package>

# Add from git
flutter pub add --dev storybook_toolkit --git-url https://github.com/org/repo.git --git-ref branch-name
```

### Project Structure

```
├── lib/
│   ├── main.dart           # App entrypoint
│   ├── app.dart            # MaterialApp.router + GoRouter + theme
│   ├── models/             # Plain Dart classes with fromJson/toJson
│   ├── providers/          # Riverpod providers
│   ├── repositories/       # Abstract interfaces + implementations
│   ├── database/           # drift tables + generated code (if using drift)
│   ├── screens/            # One directory per route
│   ├── storybook/          # Storybook entrypoint + mock data
│   ├── widgets/            # Shared reusable widgets
│   └── constants/          # Theme, colors, typography
├── specs/                  # Feature specifications (if using spec-first)
├── .env                    # Environment config (gitignored)
├── .env.example            # Template
└── pubspec.yaml
```

### Architecture Layers

```
Screens (widgets)        → read from providers, dispatch actions
Providers (Riverpod)     → async state, business logic
Repositories (abstract)  → data access boundary
API Client / Local DB    → external boundaries
```

Screens never call repositories directly — always through providers. Repositories are abstract interfaces with real and fake implementations. Fakes are injected via Riverpod provider overrides in storybook and tests.

### Key Patterns

```dart
// Riverpod provider
final stationsProvider = FutureProvider<List<Station>>((ref) {
  return ref.watch(stationRepositoryProvider).getAll();
});

// Family provider (parameterized)
final stationProvider = FutureProvider.family<Station?, String>((ref, id) {
  return ref.watch(stationRepositoryProvider).get(id);
});

// Consumer widget
class MyScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(stationsProvider);
    return dataAsync.when(
      data: (stations) => ListView(...),
      loading: () => CircularProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
    );
  }
}

// Navigation with go_router
context.push('/items/${item.id}');  // push onto stack
context.go('/login');               // replace stack
```

### Common Gotchas

- **Package management**: Use `flutter pub add`, never edit pubspec.yaml directly
- **VSCode SDK path**: Use `~` not `${env:HOME}` in `.vscode/settings.json`:

  ```json
  {"dart.flutterSdkPath": "~/.asdf/installs/flutter/3.41.6-stable"}
  ```

- **macOS entitlements**: Network requests need `com.apple.security.network.client`, keychain needs `keychain-access-groups` — both in `macos/Runner/DebugProfile.entitlements` and `Release.entitlements`
- **macOS signing**: Set development team in Xcode (Runner target → Signing & Capabilities → Team → All configurations)
- **Commit generated code separately**: After any command that generates/changes code, commit those changes with the exact command in the message BEFORE making manual edits
