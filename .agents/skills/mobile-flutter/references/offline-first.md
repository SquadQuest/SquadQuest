# Offline-First Architecture with drift

This reference covers adding drift (local SQLite) for apps that need to work without network connectivity. This is an optional add-on to the base Flutter stack.

## Three Phases

1. **Download** (online): Fetch data bundle from API, store in local drift DB
2. **Collect** (offline): All reads/writes go to local DB, no network required
3. **Sync** (online): Push dirty records back to server

There is no degraded offline mode — the UI is identical whether connected or not.

## drift Database Setup

### Table definitions (tables.dart)

```dart
import 'package:drift/drift.dart';

class LocalItems extends Table {
  TextColumn get serverId => text()();
  TextColumn get name => text()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
  IntColumn get updatedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {serverId};
}
```

### Database class (database.dart)

Use `drift_flutter` for cross-platform support (native + web):

```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [LocalItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'my_app',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }
}
```

### Web prerequisites

Download into `web/` directory:

- `sqlite3.wasm` from <https://github.com/simolus3/sqlite3.dart/releases>
- `drift_worker.js` from <https://github.com/simolus3/drift/releases>

### Generate code

```bash
dart run build_runner build --delete-conflicting-outputs
```

Always commit generated code (`database.g.dart`) in a separate commit with the exact command before making manual edits.

### Schema migrations

```dart
@override
int get schemaVersion => 2;

@override
MigrationStrategy get migration => MigrationStrategy(
  onUpgrade: (migrator, from, to) async {
    if (from < 2) {
      await migrator.addColumn(localItems, localItems.newColumn);
    }
  },
);
```

For pre-release apps with no deployed databases, reset to version 1 and delete the local DB rather than maintaining migration chains.

## Download Flow

```dart
Future<void> downloadBundle(String id) async {
  final response = await apiClient.dio.get('/items/$id/bundle');
  final data = response.data['data'];

  await db.transaction(() async {
    await db.deleteItemData(id);  // Clear old data
    await db.batch((b) {
      b.insertAll(localItems, parsedItems);
    });
  });
}
```

## Dirty Tracking

When a record is edited locally:

1. Write the new value to drift
2. Set `isDirty = true`
3. Set `updatedAt` to current timestamp

```dart
Future<void> updateField(String id, Map<String, dynamic> fields) async {
  final companion = LocalItemsCompanion(
    serverId: Value(id),
    // ... field values ...
    isDirty: const Value(true),
    updatedAt: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
  );
  await db.updateItem(companion);
}
```

## Sync Flow

```dart
Future<SyncResult> sync(String parentId) async {
  final dirtyItems = await db.getDirtyItems(parentId);
  if (dirtyItems.isEmpty) return SyncResult(syncedCount: 0, errors: []);

  final payload = dirtyItems.map((item) => {
    'id': item.serverId,
    // ... editable fields ...
  }).toList();

  final response = await apiClient.dio.post('/sync', data: {'items': payload});

  // Mark synced items as clean
  final erroredIds = /* extract from response */;
  for (final item in dirtyItems) {
    if (!erroredIds.contains(item.serverId)) {
      await db.markClean(item.serverId);
    }
  }

  return SyncResult(...);
}
```
