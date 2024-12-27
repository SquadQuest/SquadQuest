import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:go_router/go_router.dart';

import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/friend.dart';
import 'package:squadquest/models/user.dart';
import 'package:squadquest/services/profiles_cache.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/rsvps.dart';
import 'package:squadquest/controllers/friends.dart';

import 'event_section.dart';
import 'event_invite_sheet.dart';

final _rsvpsFriendsProvider = FutureProvider.autoDispose
    .family<List<RsvpFriend>, InstanceID>((ref, instanceId) async {
  final session = ref.watch(authControllerProvider);

  if (session == null) {
    return [];
  }

  final eventRsvps = await ref.watch(rsvpsPerEventProvider(instanceId).future);
  final friendsList = await ref.watch(friendsProvider.future);
  final profilesCache = ref.read(profilesCacheProvider.notifier);

  // generate list of rsvp members with friendship status and mutual friends
  final rsvpFriends = await Future.wait(eventRsvps.map((rsvp) async {
    final Friend? friendship = friendsList.firstWhereOrNull((friend) =>
        friend.status == FriendStatus.accepted &&
        ((friend.requesterId == session.user.id &&
                friend.requesteeId == rsvp.memberId) ||
            (friend.requesteeId == session.user.id &&
                friend.requesterId == rsvp.memberId)));

    final mutuals = rsvp.member!.mutuals == null
        ? null
        : await Future.wait(rsvp.member!.mutuals!.map((userId) async {
            final profile = await profilesCache.getById(userId);
            return profile;
          }));

    return (rsvp: rsvp, friendship: friendship, mutuals: mutuals);
  }).toList());

  // filter out non-friend members who haven't responded to their invitation
  return rsvpFriends
      .where((rsvpMember) =>
          rsvpMember.rsvp.memberId == session.user.id ||
          rsvpMember.rsvp.status != InstanceMemberStatus.invited ||
          rsvpMember.friendship != null)
      .toList();
});

final rsvpIcons = {
  InstanceMemberStatus.omw: const Icon(Icons.directions_run),
  InstanceMemberStatus.yes: const Icon(Icons.check_circle),
  InstanceMemberStatus.maybe: const Icon(Icons.help),
  InstanceMemberStatus.no: const Icon(Icons.cancel),
  InstanceMemberStatus.invited: const Icon(Icons.mail_outline),
};

typedef RsvpFriend = ({
  InstanceMember rsvp,
  Friend? friendship,
  List<UserProfile>? mutuals
});

class EventAttendees extends ConsumerWidget {
  final Instance event;
  final UserID? currentUserId;

  const EventAttendees({
    super.key,
    required this.event,
    this.currentUserId,
  });

  Widget _buildAttendeeSection(
    BuildContext context, {
    required String title,
    required List<RsvpFriend> attendees,
    required Color color,
  }) {
    if (attendees.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: EdgeInsets.only(bottom: 24),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      attendees.length.toString(),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          ...attendees.map(
              (rsvpFriend) => _buildAttendeeItem(context, rsvpFriend, color)),
        ],
      ),
    );
  }

  Widget _buildAttendeeItem(
      BuildContext context, RsvpFriend rsvpFriend, Color sectionColor) {
    final theme = Theme.of(context);
    final isHost = event.createdById == rsvpFriend.rsvp.memberId;
    final isCurrentUser = currentUserId == rsvpFriend.rsvp.memberId;
    final isFriendOrSelf = isCurrentUser || rsvpFriend.friendship != null;

    return Container(
      decoration: BoxDecoration(
        color: isCurrentUser
            ? theme.colorScheme.primaryContainer.withAlpha(77)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: !isFriendOrSelf
                ? CircleAvatar(
                    backgroundColor:
                        theme.colorScheme.primaryContainer.withAlpha(100),
                    child: Icon(
                      Icons.person_outline,
                      color: theme.iconTheme.color!.withAlpha(100),
                    ),
                  )
                : rsvpFriend.rsvp.member!.photo == null
                    ? const CircleAvatar(
                        child: Icon(Icons.person),
                      )
                    : CircleAvatar(
                        backgroundImage: NetworkImage(
                            rsvpFriend.rsvp.member!.photo.toString()),
                      ),
            title: Row(
              children: [
                Text(
                  rsvpFriend.rsvp.member!.displayName,
                  style: TextStyle(
                    color: isFriendOrSelf ? null : theme.disabledColor,
                  ),
                ),
                if (isCurrentUser) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'You',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
                if (isHost) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: sectionColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Host',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.surface,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: rsvpFriend.mutuals == null || isFriendOrSelf
                ? null
                : Text(
                    'Friend of ${rsvpFriend.mutuals!.map((profile) => profile.displayName).join(', ')}',
                    style: TextStyle(
                      color: isFriendOrSelf ? theme.disabledColor : null,
                    ),
                  ),
            trailing: rsvpIcons[rsvpFriend.rsvp.status],
            onTap: isFriendOrSelf
                ? () {
                    context.pushNamed('profile-view',
                        pathParameters: {'id': rsvpFriend.rsvp.memberId!});
                  }
                : null,
          ),
          if (rsvpFriend.rsvp.note != null &&
              rsvpFriend.rsvp.note!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(72, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withAlpha(80),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.format_quote,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rsvpFriend.rsvp.note!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rsvpsFriendsAsync = ref.watch(_rsvpsFriendsProvider(event.id!));

    return EventSection(
      title: 'Attendees',
      trailing: rsvpsFriendsAsync.whenOrNull(
        data: (rsvpsFriends) => OutlinedButton.icon(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (context) => EventInviteSheet(
                eventId: event.id!,
                excludeUsers: rsvpsFriends
                    .map((rsvp) => rsvp.rsvp.memberId)
                    .whereType<UserID>()
                    .toList(),
              ),
            );
          },
          icon: const Icon(Icons.person_add),
          label: const Text('Invite Friends'),
        ),
      ),
      children: rsvpsFriendsAsync.when(
        loading: () => [
          const Center(child: CircularProgressIndicator()),
        ],
        error: (error, _) => [
          Center(child: Text('Error: $error')),
        ],
        data: (rsvpsFriends) {
          if (rsvpsFriends.isEmpty) {
            return [
              const Text(
                'No one has RSVPed to this event yet. Be the first!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ];
          }

          final groupedRsvps = groupBy<RsvpFriend, InstanceMemberStatus>(
            rsvpsFriends,
            (rsvpFriend) => rsvpFriend.rsvp.status,
          );

          return [
            if (groupedRsvps.containsKey(InstanceMemberStatus.omw))
              _buildAttendeeSection(
                context,
                title: 'On My Way',
                attendees: groupedRsvps[InstanceMemberStatus.omw]!,
                color: Theme.of(context).colorScheme.tertiary,
              ),
            if (groupedRsvps.containsKey(InstanceMemberStatus.yes))
              _buildAttendeeSection(
                context,
                title: 'Going',
                attendees: groupedRsvps[InstanceMemberStatus.yes]!,
                color: Theme.of(context).colorScheme.primary,
              ),
            if (groupedRsvps.containsKey(InstanceMemberStatus.maybe))
              _buildAttendeeSection(
                context,
                title: 'Maybe',
                attendees: groupedRsvps[InstanceMemberStatus.maybe]!,
                color: Theme.of(context).colorScheme.secondary,
              ),
            if (groupedRsvps.containsKey(InstanceMemberStatus.no))
              _buildAttendeeSection(
                context,
                title: 'Not Going',
                attendees: groupedRsvps[InstanceMemberStatus.no]!,
                color: Theme.of(context).colorScheme.error,
              ),
            if (groupedRsvps.containsKey(InstanceMemberStatus.invited))
              _buildAttendeeSection(
                context,
                title: 'Invited',
                attendees: groupedRsvps[InstanceMemberStatus.invited]!,
                color: Theme.of(context).colorScheme.outline,
              ),
          ];
        },
      ),
    );
  }
}
