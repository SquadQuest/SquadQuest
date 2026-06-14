import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/message.dart';
import '../providers/providers.dart';
import 'message_attachments.dart';

/// A thread conversation (specs/behaviors/thread-drawer.md, sans the slide-in chrome
/// and realtime): the replies for a target plus a reply input. Renders as a non-scrolling
/// Column so it can embed in a ListView (activity Discussion) or a screen.
class ThreadView extends ConsumerStatefulWidget {
  const ThreadView({
    super.key,
    required this.targetType,
    required this.targetId,
    this.showAudienceHint = false,
  });

  final String targetType; // 'activity' | 'community_event' | 'message'
  final String targetId;

  /// When true, show the private-audience hint above the reply input
  /// (specs/behaviors/thread-drawer.md: "Only participants in this thread can see replies").
  final bool showAudienceHint;

  @override
  ConsumerState<ThreadView> createState() => _ThreadViewState();
}

class _ThreadViewState extends ConsumerState<ThreadView> {
  final _controller = TextEditingController();
  List<MessageAttachment> _attachments = const [];
  bool _busy = false;

  String get _key => '${widget.targetType}:${widget.targetId}';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if ((body.isEmpty && _attachments.isEmpty) || _busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(messageRepositoryProvider)
          .reply(
            widget.targetType,
            widget.targetId,
            body,
            attachments: _attachments,
          );
      _controller.clear();
      setState(() => _attachments = const []);
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
        if (widget.showAudienceHint)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 14,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Only participants in this thread can see replies',
                    key: const Key('threadAudienceHint'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        MessageAttachmentField(
          attachments: _attachments,
          enabled: !_busy,
          onChanged: (a) => setState(() => _attachments = a),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('threadReplyField'),
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onChanged: (_) => setState(() {}),
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
              onPressed:
                  (_busy ||
                      (_controller.text.trim().isEmpty && _attachments.isEmpty))
                  ? null
                  : _send,
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
          if (message.body != null && message.body!.isNotEmpty)
            Text(message.body!),
          MessageAttachmentThumbs(attachments: message.attachments),
        ],
      ),
    );
  }
}
