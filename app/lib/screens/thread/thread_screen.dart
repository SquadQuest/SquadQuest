import 'package:flutter/material.dart';

import '../../models/message.dart';
import '../../widgets/thread_view.dart';

/// A standalone thread (e.g. tapping a squad message). The root message is passed
/// as a header; replies + input come from [ThreadView]. (specs/behaviors/thread-drawer.md)
class ThreadScreen extends StatelessWidget {
  const ThreadScreen({
    super.key,
    required this.targetType,
    required this.targetId,
    this.root,
  });

  final String targetType;
  final String targetId;
  final Message? root;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thread')),
      body: ListView(
        key: const Key('threadScreen'),
        padding: const EdgeInsets.all(16),
        children: [
          if (root != null) ...[
            Text(
              root!.senderName ?? 'Someone',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(root!.body ?? ''),
            const Divider(height: 32),
          ],
          ThreadView(targetType: targetType, targetId: targetId),
        ],
      ),
    );
  }
}
