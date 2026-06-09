import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/message.dart';
import '../providers/providers.dart';

/// A thread conversation (specs/behaviors/thread-drawer.md, sans the slide-in chrome
/// and realtime): the replies for a target plus a reply input. Renders as a non-scrolling
/// Column so it can embed in a ListView (activity Discussion) or a screen.
class ThreadView extends ConsumerStatefulWidget {
  const ThreadView({
    super.key,
    required this.targetType,
    required this.targetId,
  });

  final String targetType; // 'activity' | 'message'
  final String targetId;

  @override
  ConsumerState<ThreadView> createState() => _ThreadViewState();
}

class _ThreadViewState extends ConsumerState<ThreadView> {
  final _controller = TextEditingController();
  bool _busy = false;

  String get _key => '${widget.targetType}:${widget.targetId}';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(messageRepositoryProvider)
          .reply(widget.targetType, widget.targetId, body);
      _controller.clear();
      ref.invalidate(threadProvider(_key));
      // thread_count changed → refresh the timelines that show it.
      ref.invalidate(friendsTimelineProvider);
      ref.invalidate(squadTimelineProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t send your reply.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final thread = ref.watch(threadProvider(_key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        thread.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Couldn\'t load the thread.\n$e'),
          ),
          data: (msgs) => msgs.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No replies yet. Start the conversation.'),
                )
              : Column(
                  key: const Key('threadMessages'),
                  // endpoint returns newest-first; show chronological
                  children: msgs.reversed.map(_MessageRow.new).toList(),
                ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('threadReplyField'),
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                  hintText: 'Reply…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            IconButton(
              key: const Key('threadReplySend'),
              icon: const Icon(Icons.send),
              onPressed: _busy ? null : _send,
            ),
          ],
        ),
      ],
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow(this.message);
  final Message message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.senderName ?? 'Someone',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Text(message.body ?? ''),
        ],
      ),
    );
  }
}
