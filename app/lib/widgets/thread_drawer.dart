import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity.dart';
import '../models/community.dart';
import '../models/message.dart';
import 'community_event_card.dart';
import 'message_attachments.dart';
import 'response_controls.dart';
import 'thread_view.dart';
import 'thread_vote_bar.dart';

/// What a thread drawer is opened for (specs/behaviors/thread-drawer.md). The
/// header + vote bar adapt to the variant; the conversation is the same for all.
sealed class ThreadTarget {
  const ThreadTarget();

  factory ThreadTarget.activity(Activity activity) = ActivityTarget;
  factory ThreadTarget.squadMessage(Message message) = SquadMessageTarget;
  factory ThreadTarget.communityEvent({
    required String communityId,
    required CommunityEvent event,
    bool isLeader,
  }) = CommunityEventTarget;

  /// (targetType, targetId) for the messages API + threadProvider key.
  (String, String) get thread;
}

class ActivityTarget extends ThreadTarget {
  const ActivityTarget(this.activity);
  final Activity activity;
  @override
  (String, String) get thread => ('activity', activity.id);
}

class SquadMessageTarget extends ThreadTarget {
  const SquadMessageTarget(this.message);
  final Message message;
  @override
  (String, String) get thread => ('message', message.id);
}

class CommunityEventTarget extends ThreadTarget {
  const CommunityEventTarget({
    required this.communityId,
    required this.event,
    this.isLeader = false,
  });
  final String communityId;
  final CommunityEvent event;
  final bool isLeader;
  @override
  (String, String) get thread => ('community_event', event.id);
}

/// Slide-in-from-the-right thread drawer over the whole screen (covers app bar +
/// any composer), leaving a sliver of the timeline behind a scrim — the
/// "floating" feel from specs/behaviors/thread-drawer.md. Tap the scrim or X to close.
Future<void> showThreadDrawer(
  BuildContext context, {
  required ThreadTarget target,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close thread',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => Align(
      alignment: Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.92,
        heightFactor: 1,
        child: _ThreadDrawer(target: target),
      ),
    ),
    transitionBuilder: (_, anim, _, child) => SlideTransition(
      position: Tween(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

class _ThreadDrawer extends ConsumerWidget {
  const _ThreadDrawer({required this.target});
  final ThreadTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (targetType, targetId) = target.thread;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          key: const Key('threadDrawer'),
          children: [
            // Close affordance + a thin title.
            Row(
              children: [
                IconButton(
                  key: const Key('closeThreadDrawer'),
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Expanded(child: Text('Thread')),
                const SizedBox(width: 8),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                children: [
                  _header(context, ref),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  ThreadView(
                    targetType: targetType,
                    targetId: targetId,
                    showAudienceHint: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, WidgetRef ref) => switch (target) {
    ActivityTarget(:final activity) => _ActivityHeader(activity: activity),
    CommunityEventTarget(:final communityId, :final event, :final isLeader) =>
      CommunityEventCard(
        communityId: communityId,
        event: event,
        isLeader: isLeader,
        inThread: true,
      ),
    SquadMessageTarget(:final message) => _MessageHeader(message: message),
  };
}

/// Idea/activity header: type + state + audience + inline response controls, plus the
/// persistent vote bar (when the idea warrants one).
class _ActivityHeader extends ConsumerStatefulWidget {
  const _ActivityHeader({required this.activity});
  final Activity activity;
  @override
  ConsumerState<_ActivityHeader> createState() => _ActivityHeaderState();
}

class _ActivityHeaderState extends ConsumerState<_ActivityHeader> {
  late Activity _a = widget.activity;

  @override
  Widget build(BuildContext context) {
    final a = _a;
    final stateLine = a.isConfirmed
        ? 'Confirmed · ${[a.confirmedTime, a.confirmedLocation].whereType<String>().join(' · ')}'
        : 'Idea${a.audienceSummary != null ? ' · ${a.audienceSummary}' : ''}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${a.captainName ?? 'Someone'} · ${a.activityTypeLabel ?? ''}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(stateLine, key: const Key('threadHeaderState')),
        const SizedBox(height: 8),
        // Inline + collapsing response controls (shared with the timeline tile).
        if (!a.isConfirmed)
          ResponseControls(
            activity: a,
            onChanged: (updated) => setState(() => _a = updated),
          ),
        Text(
          '${a.inCount} in · ${a.interestedCount} interested',
          key: const Key('responseCounts'),
        ),
        if (ThreadVoteBar.appliesTo(a))
          ThreadVoteBar(
            activity: a,
            onChanged: (updated) => setState(() => _a = updated),
          ),
      ],
    );
  }
}

/// Squad message header: sender + body preview, no voting.
class _MessageHeader extends StatelessWidget {
  const _MessageHeader({required this.message});
  final Message message;
  @override
  Widget build(BuildContext context) {
    final m = message;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          m.senderName ?? 'Someone',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (m.body != null && m.body!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(m.body!),
        ],
        MessageAttachmentThumbs(attachments: m.attachments),
      ],
    );
  }
}
