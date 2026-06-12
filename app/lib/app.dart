import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/providers.dart';
import 'router.dart';

class SquadQuestApp extends ConsumerWidget {
  const SquadQuestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the realtime SSE connection alive for the app's lifetime (it self-gates
    // on auth state; a dropped stream is harmless — see specs/behaviors/realtime.md).
    ref.watch(realtimeConnectionProvider);
    return MaterialApp.router(
      title: 'SquadQuest',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
        useMaterial3: true,
      ),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
