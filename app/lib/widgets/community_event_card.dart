import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/activity.dart';
import '../models/community.dart';
import '../providers/active_context.dart';
import '../providers/providers.dart';
import 'thread_drawer.dart';

/// A born-confirmed community event card with the dual-attendance display and the
/// RSVP visibility gradient (specs/screens/communities.md): an anonymous headcount,
/// an opt-in public face-pile, and Going / Show-name toggles. "Show name" implies
/// going; going never escalates to public on its own.
class CommunityEventCard extends ConsumerStatefulWidget {
  const CommunityEventCard({
    super.key,
    required this.communityId,
    required this.event,
    this.isLeader = false,
    this.inThread = false,
  });

  final String communityId;
  final CommunityEvent event;
  final bool isLeader;

  /// When true the card is the thread drawer's header: it drops its own tap-to-open
  /// (you're already in the thread) and renders flush (no Card margin/elevation).
  final bool inThread;

  @override
  ConsumerState<CommunityEventCard> createState() => _CommunityEventCardState();
}

class _CommunityEventCardState extends ConsumerState<CommunityEventCard> {
  bool _busy = false;

  Future<void> _rsvp({required bool going, required bool public}) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(communityRepositoryProvider)
          .rsvp(widget.event.id, going: going, public: public);
      ref.invalidate(communityEventsProvider(widget.communityId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t update your RSVP.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this event?'),
        content: Text(widget.event.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            key: const Key('confirmDeleteEvent'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel event'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(communityRepositoryProvider).deleteEvent(widget.event.id);
      ref.invalidate(communityEventsProvider(widget.communityId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t cancel the event.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final facePile = e.publicGoing.isEmpty
        ? null
        : '${e.publicGoing.take(2).join(', ')}'
              '${e.publicGoing.length > 2 ? ' +${e.publicGoing.length - 2}' : ''} publicly';

    return Card(
      margin: widget.inThread
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      // Tapping the card opens the event's thread drawer (chat + RSVP discussion).
      // The RSVP chips / leader menu have their own handlers, so they win their
      // own taps; this catches the rest. In-thread the card IS the drawer header,
      // so it doesn't re-open itself. See specs/behaviors/thread-drawer.md.
      child: InkWell(
        key: Key('openEventThread_${e.id}'),
        onTap: widget.inThread
            ? null
            : () => showThreadDrawer(
                context,
                target: ThreadTarget.communityEvent(
                  communityId: widget.communityId,
                  event: e,
                  isLeader: widget.isLeader,
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${e.communityIcon ?? '📣'}  ${e.communityName ?? 'Community'}'
                      '${e.recurrence != null ? ' · ${e.recurrence}' : ''}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  if (widget.isLeader)
                    SizedBox(
                      height: 28,
                      child: PopupMenuButton<String>(
                        key: Key('event_menu_${e.id}'),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.more_vert, size: 20),
                        onSelected: (v) {
                          if (v == 'edit') {
                            context.push(
                              '/communities/${widget.communityId}/events/new',
                              extra: e,
                            );
                          } else if (v == 'delete') {
                            _delete();
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Cancel event'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(e.title, style: Theme.of(context).textTheme.titleMedium),
              if (e.time != null || e.location != null) ...[
                const SizedBox(height: 4),
                Text([e.time, e.location].whereType<String>().join(' · ')),
              ],
              const SizedBox(height: 10),
              Text(
                '${e.goingCount} going'
                '${facePile != null ? '  ·  $facePile' : ''}',
                key: Key('going_${e.id}'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    key: Key('going_toggle_${e.id}'),
                    label: const Text('Going'),
                    selected: e.youGoing,
                    onSelected: _busy
                        ? null
                        : (sel) => _rsvp(
                            going: sel,
                            public: sel ? e.youPublic : false,
                          ),
                  ),
                  FilterChip(
                    key: Key('public_toggle_${e.id}'),
                    label: const Text('Show my name'),
                    selected: e.youPublic,
                    onSelected: _busy
                        ? null
                        : (sel) => _rsvp(going: true, public: sel),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: Key('bring_friends_${e.id}'),
                  icon: const Icon(Icons.group_add, size: 18),
                  label: const Text('Bring friends'),
                  // Switch to My Friends + open the composer pre-filled with this event
                  // (bring-friends bridge): posts a friends-scoped idea, never the public event.
                  onPressed: () {
                    ref.read(activeContextProvider.notifier).toFriends();
                    context.push(
                      '/ideas/new',
                      extra: EventRef(
                        id: e.id,
                        title: e.title,
                        time: e.time,
                        location: e.location,
                        communityName: e.communityName,
                        communityIcon: e.communityIcon,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
