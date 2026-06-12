import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/activity.dart';
import '../../models/feed_item.dart';
import '../../models/message.dart';
import '../../providers/active_context.dart';
import '../../providers/auth_controller.dart';
import '../../providers/providers.dart';
import '../../widgets/community_event_card.dart';
import '../../widgets/message_attachments.dart';

/// The active timeline, per the context selector (specs/behaviors/context-selector.md):
/// My Friends (ideas/activities), a Squad (heterogeneous activities + messages), or a
/// Community (leader-broadcast event cards, RSVP, no posting). One source of truth:
/// `activeContextProvider`.
class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(activeContextProvider);
    final isCommunity = ctx is CommunityContext;
    final title = switch (ctx) {
      FriendsContext() => 'My Friends',
      SquadContext(:final name) => name,
      CommunityContext(:final name) => name,
    };
    // The active community (for leader controls), if any.
    final activeCommunity = ctx is CommunityContext
        ? ref.watch(activeCommunityProvider(ctx.id))
        : null;
    final isLeader = activeCommunity?.isLeader ?? false;

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          key: const Key('contextSelectorButton'),
          onTap: () => _showContextSelector(context, ref),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
        actions: [
          if (isLeader && activeCommunity != null)
            IconButton(
              key: const Key('editCommunityButton'),
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit community',
              onPressed: () =>
                  context.push('/communities/new', extra: activeCommunity),
            ),
          IconButton(
            key: const Key('peopleButton'),
            icon: const Icon(Icons.people_outline),
            tooltip: 'People',
            onPressed: () => context.push('/friends'),
          ),
          // Tap your avatar → profile (view/edit name+photo, sign out).
          _ProfileAvatarButton(
            photo: ref
                .watch(authControllerProvider.notifier)
                .currentProfile
                ?.photo,
          ),
          const SizedBox(width: 8),
        ],
      ),
      // Communities are leaders-broadcast: followers don't compose here.
      floatingActionButton: isCommunity
          ? null
          : FloatingActionButton(
              key: const Key('composeIdeaFab'),
              tooltip: 'New idea',
              onPressed: () => context.push('/ideas/new'),
              child: const Icon(Icons.add),
            ),
      body: switch (ctx) {
        CommunityContext(:final id) => _CommunityBody(
          communityId: id,
          isLeader: isLeader,
        ),
        _ => _FeedBody(ctx: ctx),
      },
    );
  }

  void _showContextSelector(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => Consumer(
        builder: (_, ref, _) {
          final squads = ref.watch(squadsProvider);
          final communities = ref.watch(communitiesProvider(''));
          return SafeArea(
            child: ListView(
              key: const Key('contextSelectorSheet'),
              shrinkWrap: true,
              children: [
                const _SheetHeader('MY FRIENDS'),
                ListTile(
                  key: const Key('ctx_friends'),
                  leading: const Icon(Icons.group),
                  title: const Text('My Friends'),
                  onTap: () {
                    ref.read(activeContextProvider.notifier).toFriends();
                    Navigator.pop(sheetContext);
                  },
                ),
                const _SheetHeader('SQUADS'),
                ...squads.maybeWhen(
                  data: (list) => list.map(
                    (s) => ListTile(
                      key: Key('ctx_squad_${s.id}'),
                      leading: const Icon(Icons.shield_outlined),
                      title: Text(s.name),
                      subtitle: Text('${s.memberCount} members · ${s.role}'),
                      onTap: () {
                        ref
                            .read(activeContextProvider.notifier)
                            .toSquad(s.id, s.name);
                        Navigator.pop(sheetContext);
                      },
                    ),
                  ),
                  orElse: () => [
                    const ListTile(dense: true, title: Text('Loading…')),
                  ],
                ),
                ListTile(
                  key: const Key('ctx_new_squad'),
                  leading: const Icon(Icons.add),
                  title: const Text('New squad'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push('/squads/new');
                  },
                ),
                const _SheetHeader('COMMUNITIES'),
                ...communities.maybeWhen(
                  data: (list) => list
                      .where((c) => c.youFollow)
                      .map(
                        (c) => ListTile(
                          key: Key('ctx_community_${c.id}'),
                          leading: Text(
                            c.icon ?? '📣',
                            style: const TextStyle(fontSize: 20),
                          ),
                          title: Text(c.name),
                          subtitle: Text('${c.followerCount} followers'),
                          onTap: () {
                            ref
                                .read(activeContextProvider.notifier)
                                .toCommunity(c.id, c.name);
                            Navigator.pop(sheetContext);
                          },
                        ),
                      ),
                  orElse: () => [
                    const ListTile(dense: true, title: Text('Loading…')),
                  ],
                ),
                ListTile(
                  key: const Key('ctx_discover'),
                  leading: const Icon(Icons.travel_explore),
                  title: const Text('Discover communities'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push('/communities');
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// App-bar avatar that opens the profile screen. Shows the user's photo, or a
/// person glyph when none is set (so the entry point is always visible).
class _ProfileAvatarButton extends StatelessWidget {
  const _ProfileAvatarButton({this.photo});

  final String? photo;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photo != null && photo!.isNotEmpty;
    return IconButton(
      key: const Key('profileButton'),
      tooltip: 'Profile',
      onPressed: () => context.push('/profile'),
      icon: CircleAvatar(
        radius: 14,
        foregroundImage: hasPhoto ? NetworkImage(photo!) : null,
        child: hasPhoto ? null : const Icon(Icons.person, size: 18),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(
      label,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
    ),
  );
}

/// My Friends / Squad: the unified activities(+messages) feed + (squad) composer.
class _FeedBody extends ConsumerWidget {
  const _FeedBody({required this.ctx});
  final ActiveContext ctx;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<FeedItem>> feed = switch (ctx) {
      SquadContext(:final id) =>
        ref.watch(squadTimelineProvider(id)).whenData((p) => p.items),
      _ =>
        ref
            .watch(friendsTimelineProvider)
            .whenData(
              (p) => p.items.map<FeedItem>(ActivityFeedItem.new).toList(),
            ),
    };
    final emptyText = switch (ctx) {
      SquadContext() =>
        'Nothing here yet.\nShare an idea (+) or post a message below.',
      _ => 'No ideas yet.\nWhen a friend shares an idea, it shows up here.',
    };

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => switch (ctx) {
              SquadContext(:final id) => ref.refresh(
                squadTimelineProvider(id).future,
              ),
              _ => ref.refresh(friendsTimelineProvider.future),
            },
            child: feed.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Text(
                      'Couldn\'t load this timeline.\n$e',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              data: (items) {
                if (items.isEmpty) {
                  return ListView(
                    children: [
                      const SizedBox(height: 160),
                      Center(
                        key: const Key('timelineEmpty'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(emptyText, textAlign: TextAlign.center),
                        ),
                      ),
                    ],
                  );
                }
                return ListView.separated(
                  key: const Key('timelineList'),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) => switch (items[i]) {
                    ActivityFeedItem(:final activity) => _ActivityTile(
                      activity,
                    ),
                    MessageFeedItem(:final message) => _MessageTile(message),
                  },
                );
              },
            ),
          ),
        ),
        if (ctx is SquadContext)
          _SquadComposer(squadId: (ctx as SquadContext).id),
      ],
    );
  }
}

/// Community: leader-broadcast event cards. Followers see a read-only banner;
/// leaders see a Post-event affordance + per-card edit/delete.
class _CommunityBody extends ConsumerWidget {
  const _CommunityBody({required this.communityId, this.isLeader = false});
  final String communityId;
  final bool isLeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(communityEventsProvider(communityId));
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.refresh(communityEventsProvider(communityId).future),
            child: events.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Text(
                      'Couldn\'t load events.\n$e',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              data: (list) => list.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 160),
                        Center(
                          key: Key('communityEmpty'),
                          child: Text('No upcoming events.'),
                        ),
                      ],
                    )
                  : ListView(
                      key: const Key('communityEvents'),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        for (final e in list)
                          CommunityEventCard(
                            communityId: communityId,
                            event: e,
                            isLeader: isLeader,
                          ),
                      ],
                    ),
            ),
          ),
        ),
        if (isLeader)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: FilledButton.icon(
                key: const Key('postEventButton'),
                onPressed: () =>
                    context.push('/communities/$communityId/events/new'),
                icon: const Icon(Icons.add),
                label: const Text('Post event'),
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Text(
              'Following · only leaders post events here',
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile(this.activity);
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final base = a.isConfirmed
        ? [a.confirmedTime, a.confirmedLocation].whereType<String>().join(' · ')
        : 'Idea · ${a.audienceSummary ?? ''}';
    // Brought-along ideas show the embedded community event.
    final subtitle = a.eventRef != null
        ? '$base · ${a.eventRef!.communityIcon ?? '📣'} ${a.eventRef!.communityName ?? 'Community'}'
        : base;
    return ListTile(
      onTap: () => context.push('/activity/${a.id}', extra: a),
      leading: CircleAvatar(
        child: Text((a.captainName ?? '?').characters.first),
      ),
      title: Text(
        '${a.captainName ?? 'Someone'} · ${a.activityTypeLabel ?? ''}',
      ),
      subtitle: Text(subtitle),
      trailing: a.isConfirmed
          ? const Icon(Icons.event_available)
          : Text('${a.inCount} in'),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile(this.message);
  final Message message;

  @override
  Widget build(BuildContext context) {
    final m = message;
    return ListTile(
      key: Key('message_${m.id}'),
      onTap: () => context.push('/thread/message/${m.id}', extra: m),
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        child: Text((m.senderName ?? '?').characters.first),
      ),
      title: Text(m.senderName ?? 'Someone'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (m.body != null && m.body!.isNotEmpty) Text(m.body!),
          MessageAttachmentThumbs(attachments: m.attachments),
        ],
      ),
      isThreeLine: m.attachments.isNotEmpty,
      trailing: m.threadCount > 0
          ? Text('${m.threadCount} ${m.threadCount == 1 ? 'reply' : 'replies'}')
          : null,
    );
  }
}

class _SquadComposer extends ConsumerStatefulWidget {
  const _SquadComposer({required this.squadId});
  final String squadId;
  @override
  ConsumerState<_SquadComposer> createState() => _SquadComposerState();
}

class _SquadComposerState extends ConsumerState<_SquadComposer> {
  final _controller = TextEditingController();
  List<MessageAttachment> _attachments = const [];
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    // A message needs text or at least one attachment (photo-only is valid).
    if ((body.isEmpty && _attachments.isEmpty) || _busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(messageRepositoryProvider)
          .postSquadMessage(widget.squadId, body, attachments: _attachments);
      _controller.clear();
      setState(() => _attachments = const []);
      ref.invalidate(squadTimelineProvider(widget.squadId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t send. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSend =
        !_busy &&
        (_controller.text.trim().isNotEmpty || _attachments.isNotEmpty);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MessageAttachmentField(
              attachments: _attachments,
              enabled: !_busy,
              onChanged: (a) => setState(() => _attachments = a),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('squadMessageField'),
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Message your squad…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('squadMessageSend'),
                  icon: const Icon(Icons.send),
                  onPressed: canSend ? _send : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
