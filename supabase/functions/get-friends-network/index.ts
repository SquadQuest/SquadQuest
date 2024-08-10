import { assertGet, HttpError, serve } from "../_shared/http.ts";
import { scrubProfile } from "../_shared/squadquest.ts";
import {
  getServiceRoleSupabaseClient,
  getSupabaseUser,
} from "../_shared/supabase.ts";

interface NetworkEntry {
  mutuals: Set<string>;
  first_name?: string;
  last_name?: string;
  photo?: string | null;
}

serve(async (request) => {
  console.log("handling request", request.url);
  const network = new Map<string, NetworkEntry>();

  // process request
  assertGet(request);

  // connect to Supabase
  const serviceRoleSupabase = getServiceRoleSupabaseClient();

  // get current user
  const currentUser = await getSupabaseUser(request);
  if (!currentUser) {
    throw new HttpError(
      "Authorized user not found",
      403,
      "authorized-user-not-found",
    );
  }

  // get list of user's friends
  const { data: friends } = await serviceRoleSupabase
    .from(
      "friends",
    )
    .select("requester, requestee")
    .or(
      `status.eq."accepted",and(status.eq."requested", requestee.eq."${
        currentUser!.id
      }")`,
    )
    .or(`requester.eq."${currentUser!.id}", requestee.eq."${currentUser!.id}"`)
    .throwOnError();

  const friendIds = new Set();
  for (const friendship of friends!) {
    const friendId = friendship.requester == currentUser!.id
      ? friendship.requestee
      : friendship.requester;

    friendIds.add(friendId);
    network.set(friendId, { mutuals: new Set() });
  }

  // get full profiles of friends and add to network
  const { data: friendProfiles } = await serviceRoleSupabase.from(
    "profiles",
  )
    .select("*")
    .in("id", Array.from(friendIds))
    .throwOnError();

  for (const profile of friendProfiles!) {
    Object.assign(network.get(profile.id)!, {
      ...await scrubProfile(profile, true),
      id: undefined,
    });
  }

  console.log("got friend profiles", friendProfiles?.length);

  // get friends of friends
  const friendIdsList = `("${Array.from(friendIds).join('","')}")`;
  const { data: friendsOfFriends } = await serviceRoleSupabase
    .from(
      "friends",
    )
    .select("requester, requestee")
    .eq("status", "accepted")
    .or(
      `requester.in.${friendIdsList}, requestee.in.${friendIdsList}`,
    )
    .throwOnError();
  console.log("got friendsOfFriends", friendsOfFriends?.length);

  // accrue new IDs from results
  const friendOfFriendIds = new Set();
  for (const friendship of friendsOfFriends!) {
    // process friendship link in both directions
    for (
      const [userId1, userId2] of [
        [friendship.requester, friendship.requestee],
        [friendship.requestee, friendship.requester],
      ]
    ) {
      // skip current user
      if (userId1 == currentUser.id) {
        continue;
      }

      // add id to friend-of-friend set if they're not a direct friend or the current user
      if (!friendIds.has(userId1)) {
        friendOfFriendIds.add(userId1);
      }

      // get or initialize network entry
      let networkEntry = network.get(userId1);
      if (!networkEntry) {
        networkEntry = { mutuals: new Set() };
        network.set(userId1, networkEntry);
      }

      // add mutual friend link
      if (friendIds.has(userId2)) {
        networkEntry.mutuals.add(userId2);
      }
    }
  }
  console.log("collected friendOfFriendIds", friendOfFriendIds);

  // get anonymized profiles of friends of friends
  const { data: friendOfFriendProfiles } = await serviceRoleSupabase.from(
    "profiles_anonymous",
  )
    .select("*")
    .in("id", Array.from(friendOfFriendIds))
    .throwOnError();

  for (const profile of friendOfFriendProfiles!) {
    Object.assign(network.get(profile.id)!, {
      first_name: profile.first_name,
    });
  }

  console.log("got friend of friend profiles", friendOfFriendProfiles?.length);

  // serialize maps and sets
  const networkEntries = Array.from(network).map(
    (
      [userId, networkEntry],
    ) => ({
      ...networkEntry,
      id: userId,
      mutuals: Array.from(networkEntry.mutuals),
    }),
  );

  // return friend network data
  return new Response(
    JSON.stringify(networkEntries),
    {
      headers: { "Content-Type": "application/json" },
      status: 200,
    },
  );
});
