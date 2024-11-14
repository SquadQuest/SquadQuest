import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/common.dart';
import 'package:squadquest/models/friend.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/user.dart';
import 'package:squadquest/services/profiles_cache.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/rsvps.dart';
import 'package:squadquest/controllers/friends.dart';

final statusGroupOrder = <InstanceMemberStatus, int>{
  InstanceMemberStatus.omw: 0,
  InstanceMemberStatus.yes: 1,
  InstanceMemberStatus.maybe: 2,
  InstanceMemberStatus.no: 3,
  InstanceMemberStatus.invited: 4,
};

typedef RsvpFriend = ({
  InstanceMember rsvp,
  Friend? friendship,
  List<UserProfile>? mutuals
});

final rsvpsFriendsProvider = FutureProvider.autoDispose
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
