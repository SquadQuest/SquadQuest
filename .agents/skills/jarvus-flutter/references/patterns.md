# Flutter Architecture Patterns

## Riverpod State Management

### Provider types

```dart
// Simple value (e.g. database instance, API client)
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// Async data (e.g. fetch from DB or API)
final stationsProvider = FutureProvider<List<Station>>((ref) {
  return ref.watch(stationRepositoryProvider).getAll();
});

// Parameterized (e.g. fetch one item by ID)
final stationProvider = FutureProvider.family<Station?, String>((ref, id) {
  return ref.watch(stationRepositoryProvider).get(id);
});

// Compound parameter (use a record)
final pathwaysProvider = FutureProvider.family<List<Pathway>,
    ({String stationId, String levelId})>((ref, params) {
  return ref.watch(pathwayRepositoryProvider)
      .getForLevel(params.stationId, params.levelId);
});
```

### Invalidation

When data changes (e.g. after a save), invalidate providers so dependents re-fetch:

```dart
// In a callback
ref.invalidate(stationsProvider);
ref.invalidate(stationProvider(stationId));

// Invalidate family providers broadly (all parameters)
ref.invalidate(pathwaysProvider);
```

### Consumer widgets

```dart
class StationScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(stationProvider(stationId));

    if (dataAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (dataAsync.hasError) {
      return ErrorScreen(
        message: 'Failed to load.',
        onRetry: () => ref.invalidate(stationProvider(stationId)),
      );
    }

    final station = dataAsync.value;
    // ...
  }
}
```

For stateful interactions (loading flags, form state), use `ConsumerStatefulWidget`.

## Repository Pattern

### Abstract interface

```dart
abstract class StationRepository {
  Future<List<Station>> getAll();
  Future<Station?> get(String id);
}
```

### Real implementation (API + local DB)

```dart
class ApiStationRepository implements StationRepository {
  final ApiClient apiClient;
  final AppDatabase db;

  ApiStationRepository({required this.apiClient, required this.db});

  @override
  Future<List<Station>> getAll() async {
    final rows = await db.getAllStations();
    return rows.map(_fromRow).toList();
  }
}
```

### Fake implementation (for storybook/tests)

```dart
class FakeStationRepository implements StationRepository {
  final List<Station> _stations;
  FakeStationRepository(this._stations);

  @override
  Future<List<Station>> getAll() async => _stations;
}
```

### Provider wiring

```dart
final stationRepositoryProvider = Provider<StationRepository>((ref) {
  return ApiStationRepository(
    apiClient: ref.watch(apiClientProvider),
    db: ref.watch(databaseProvider),
  );
});
```

In storybook, override with fakes:

```dart
ProviderScope(
  overrides: [
    stationRepositoryProvider.overrideWithValue(
      FakeStationRepository(mockStations),
    ),
  ],
  child: MyApp(),
)
```

## Model Classes

Hand-written, no code generation. Include `fromJson`, `toJson`, and `copyWith`:

```dart
class Station {
  final String id;
  final String name;
  final DateTime? downloadedAt;

  const Station({required this.id, required this.name, this.downloadedAt});

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['id'] as String,
      name: json['name'] as String,
      downloadedAt: json['downloaded_at'] != null
          ? DateTime.parse(json['downloaded_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'downloaded_at': downloadedAt?.toIso8601String(),
  };
}
```

For nullable fields in `copyWith`, use the `Function()?` pattern:

```dart
Station copyWith({
  String? id,
  String? name,
  DateTime? Function()? downloadedAt,  // nullable wrapper
}) {
  return Station(
    id: id ?? this.id,
    name: name ?? this.name,
    downloadedAt: downloadedAt != null ? downloadedAt() : this.downloadedAt,
  );
}
```

## Routing with go_router

```dart
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      final isLoggedIn = await ApiClient.hasToken();
      final isLoginRoute = state.matchedLocation == '/login';
      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'items/:id',
            builder: (context, state) => ItemScreen(
              id: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
    ],
  );
});
```

Use `context.push()` for forward navigation (builds back stack), `context.go()` for replacing (login redirects).

## Screen Widgets as Route Wrappers

Keep screen widgets prop-driven (no provider dependencies) so they work in storybook. Create route wrapper widgets that connect providers to screens:

```dart
// The screen (prop-driven, storybook-friendly)
class TaskListScreen extends StatelessWidget {
  final String title;
  final List<Pathway> pathways;
  final void Function(Pathway)? onTap;

  const TaskListScreen({required this.title, required this.pathways, this.onTap});
  // ...
}

// The route wrapper (connects providers)
class _TaskListRoute extends ConsumerWidget {
  final String stationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathwaysAsync = ref.watch(pathwaysProvider((stationId: stationId, ...)));

    if (pathwaysAsync.isLoading) return const LoadingScreen();
    if (pathwaysAsync.hasError) return ErrorScreen(onRetry: () => ref.invalidate(...));

    return TaskListScreen(
      title: 'My List',
      pathways: pathwaysAsync.value ?? [],
      onTap: (pw) => context.push('/items/${pw.id}'),
    );
  }
}
```

## API Client with JWT

```dart
class ApiClient {
  late final Dio dio;

  ApiClient() {
    dio = Dio(BaseOptions(
      baseUrl: dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000/api',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (!options.path.contains('/auth/login')) {
          final token = await getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
    ));
  }
}
```
