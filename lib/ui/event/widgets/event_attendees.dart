import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';

import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/friend.dart';
import 'package:squadquest/models/user.dart';
import 'package:squadquest/controllers/rsvps.dart';
import 'package:squadquest/controllers/friends.dart';

import 'event_section.dart';
import 'event_invite_sheet.dart';

final _rsvpsFriendsProvider =
    Provider.family<AsyncValue<List<RsvpFriend>>, InstanceID>((ref, eventId) {
  final eventRsvpsAsync = ref.watch(rsvpsPerEventProvider(eventId));
  final friendsAsync = ref.watch(friendsProvider);

  return eventRsvpsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
    data: (rsvps) => friendsAsync.when(
      loading: () => const AsyncValue.loading(),
      error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
      data: (friends) {
        final List<RsvpFriend> rsvpFriends = [];
        for (final rsvp in rsvps) {
          if (rsvp.member == null || rsvp.memberId == null) continue;

          final friendship = friends.firstWhereOrNull(
            (f) =>
                f.requesterId == rsvp.memberId ||
                f.requesteeId == rsvp.memberId,
          );

          final mutuals = friends
              .where((f) =>
                  f.requesterId == rsvp.memberId ||
                  f.requesteeId == rsvp.memberId)
              .map((f) => f.getOtherProfile(rsvp.memberId!))
              .whereType<UserProfile>()
              .toList();

          rsvpFriends.add((
            rsvp: rsvp,
            friendship: friendship,
            mutuals: mutuals.isEmpty ? null : mutuals,
          ));
        }

        return AsyncValue.data(rsvpFriends);
      },
    ),
  );
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
  final InstanceID eventId;

  const EventAttendees({
    super.key,
    required this.eventId,
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
    final isFriendOrSelf = rsvpFriend.friendship != null;

    return ListTile(
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
                  backgroundImage:
                      NetworkImage(rsvpFriend.rsvp.member!.photo.toString()),
                ),
      title: Text(
        rsvpFriend.rsvp.member!.displayName,
        style: TextStyle(
          color: isFriendOrSelf ? null : theme.disabledColor,
        ),
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
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rsvpsFriendsAsync = ref.watch(_rsvpsFriendsProvider(eventId));

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
                eventId: eventId,
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
