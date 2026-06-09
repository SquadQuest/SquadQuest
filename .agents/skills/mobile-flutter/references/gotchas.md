# Common Gotchas

## Package Management

**Never edit pubspec.yaml directly.** Always use:

```bash
flutter pub add <package>
flutter pub add --dev <package>
flutter pub add --dev <pkg> --git-url <url> --git-ref <branch>
```

The CLI resolves to the latest compatible version and updates the lock file atomically. Editing manually risks pinning outdated versions.

## Commit Generated Code

After running any command that generates or changes code (`flutter create`, `dart run build_runner build`, `flutter pub add`), **always commit those changes with the exact command documented** before making manual edits. This keeps generated code separate from hand-written code in git history.

```
feat: initialize Flutter project

Ran: flutter create my_app --empty --platforms ios,android,macos,web
```

## VSCode Settings

Use `~` for the home directory in `.vscode/settings.json`, not `${env:HOME}`:

```json
{
    "dart.flutterSdkPath": "~/.asdf/installs/flutter/3.41.6-stable"
}
```

`${env:HOME}` is not interpolated by VSCode's settings parser.

## macOS Sandbox Entitlements

### Network requests fail silently

The macOS app sandbox blocks outgoing HTTP by default. Add to both `macos/Runner/DebugProfile.entitlements` and `Release.entitlements`:

```xml
<key>com.apple.security.network.client</key>
<true/>
```

### Keychain access (flutter_secure_storage)

`flutter_secure_storage` needs keychain access:

```xml
<key>keychain-access-groups</key>
<array>
    <string>$(AppIdentifierPrefix)com.example.myApp</string>
</array>
```

This requires a signed build. Set the development team in Xcode: Runner target → Signing & Capabilities → Team → select for "All" configurations. This is a one-time Xcode setup that can't be done from the command line.

## API Numeric Fields as Strings

Some backends serialize decimal/numeric fields as strings in JSON (`"4.50"` not `4.5`). Dart's `as num?` cast will throw a `TypeError` on strings. Always use a helper that handles both:

```dart
double? toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
```

## Numeric Input Fields

`int.tryParse("45.")` returns null. If you're auto-saving on every keystroke, only save when the parse succeeds — don't null out the field on intermediate typing states like trailing decimals:

```dart
onChanged: (v) {
  if (v.isEmpty) {
    onSave(null);
  } else {
    final parsed = int.tryParse(v);
    if (parsed != null) onSave(parsed);
    // Don't save on parse failure — wait for valid input
  }
},
```

## Provider Invalidation on Navigation

`FutureProvider` caches results. When you navigate back from a screen where data was modified, the previous screen's provider still has stale data. Wrap screens in `PopScope` to invalidate on pop:

```dart
PopScope(
  onPopInvokedWithResult: (didPop, _) {
    if (didPop) {
      ref.invalidate(itemsProvider);
      ref.invalidate(statsProvider);
    }
  },
  child: MyScreen(...),
)
```

---

## drift-specific (if using local SQLite)

### Schema Changes

drift doesn't auto-migrate. When you change table definitions:

1. Bump `schemaVersion`
2. Add migration logic in `MigrationStrategy.onUpgrade`
3. Regenerate: `dart run build_runner build --delete-conflicting-outputs`
4. Commit the generated code separately

For pre-release apps, you can reset to version 1 and delete the local DB instead of maintaining migration chains. On macOS, the DB lives in `~/Library/Containers/<bundle-id>/Data/Documents/`.

### Web Support

drift uses native FFI by default, which doesn't work on web. Use `drift_flutter` package for cross-platform support:

```dart
import 'package:drift_flutter/drift_flutter.dart';

static QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'my_app',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
```

Download `sqlite3.wasm` and `drift_worker.js` from their respective GitHub releases into `web/`.

### riverpod_lint vs drift_dev

These two dev dependencies often require incompatible `analyzer` versions. If you hit a version resolution failure, drop `riverpod_lint` — drift is more essential for offline architecture than Riverpod linting.

### insertOnConflictUpdate Requires All Fields

drift's `insertOnConflictUpdate` validates all non-nullable fields even for updates. If you only need to update a few columns on an existing row, use a direct update query instead:

```dart
// Wrong — throws if required fields are Value.absent()
await into(table).insertOnConflictUpdate(companion);

// Right — only updates the specified columns
await (update(table)..where((t) => t.id.equals(id)))
    .write(LocalItemsCompanion(myField: Value(newValue)));
```
