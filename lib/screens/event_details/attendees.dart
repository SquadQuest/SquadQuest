import 'package:flutter/material.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:go_router/go_router.dart';

import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/user.dart';
import 'package:squadquest/screens/event_details/providers.dart';

class EventDetailsAttendees extends StatelessWidget {
  final List<RsvpFriend> rsvpsFriends;
  final UserID currentUserId;

  const EventDetailsAttendees({
    super.key,
    required this.rsvpsFriends,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (rsvpsFriends.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'No one has RSVPed to this event yet. Be the first! And then invite your friends with the button below.',
          style: TextStyle(fontSize: 20),
        ),
      );
    }

    return GroupedListView<RsvpFriend, InstanceMemberStatus>(
      primary: false,
      shrinkWrap: true,
      elements: rsvpsFriends,
      groupBy: (RsvpFriend rsvpFriend) => rsvpFriend.rsvp.status,
      groupComparator: (group1, group2) {
        return statusGroupOrder[group1]!.compareTo(statusGroupOrder[group2]!);
      },
      groupSeparatorBuilder: (InstanceMemberStatus group) => Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            switch (group) {
              InstanceMemberStatus.omw => 'OMW!',
              InstanceMemberStatus.yes => 'Attending',
              InstanceMemberStatus.maybe => 'Might be attending',
              InstanceMemberStatus.no => 'Not attending',
              InstanceMemberStatus.invited => 'Invited',
            },
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18),
          )),
      itemBuilder: (context, rsvpFriend) {
        final isFriendOrSelf = rsvpFriend.rsvp.memberId! == currentUserId ||
            rsvpFriend.friendship != null;
        return ListTile(
            onTap: isFriendOrSelf
                ? () {
                    context.pushNamed('profile-view',
                        pathParameters: {'id': rsvpFriend.rsvp.memberId!});
                  }
                : null,
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
            title: Text(rsvpFriend.rsvp.member!.displayName,
                style: TextStyle(
                  color: isFriendOrSelf ? null : theme.disabledColor,
                )),
            subtitle: rsvpFriend.mutuals == null || isFriendOrSelf
                ? null
                : Text(
                    // ignore: prefer_interpolation_to_compose_strings
                    'Friend of ${rsvpFriend.mutuals!.map((profile) => profile.displayName).join(', ')}',
                    style: TextStyle(
                      color: isFriendOrSelf ? theme.disabledColor : null,
                    )),
            trailing: rsvpIcons[rsvpFriend.rsvp.status]);
      },
    );
  }
}
