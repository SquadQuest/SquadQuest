import {
  assertGet,
  getRequiredQueryParameters,
  HttpError,
  serve,
} from "../_shared/http.ts";
import {
  getServiceRoleSupabaseClient,
  getSupabaseUser,
  getSupabaseUserProfile,
} from "../_shared/supabase.ts";
import { scrubProfile } from "../_shared/squadquest.ts";

serve(async (request) => {
  // process request
  assertGet(request);
  const { user_id: userId } = getRequiredQueryParameters(
    request,
    [
      "user_id",
    ],
  );

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

  // get friend
  const { data: friend } = await serviceRoleSupabase
    .from(
      "friends",
    )
    .select("*")
    .in("requester", [userId, currentUser.id])
    .in("requestee", [userId, currentUser.id])
    .maybeSingle()
    .throwOnError();

  if (!friend) {
    throw new HttpError(
      "No friend request found matching that user_id",
      404,
      "friend-not-found",
    );
  }

  // only allow fetching profile for accepted or incoming friendships
  if (
    friend.status != "accepted" && friend.status != "requested" &&
    friend.requestee != currentUser.id
  ) {
    throw new HttpError(
      "Friendship is not accepted or incoming",
      400,
      "friend-not-accepted-or-incoming",
    );
  }

  // get friend's profile
  const friendProfile = await getSupabaseUserProfile(
    request,
    friend.requestee == currentUser.id ? friend.requester : friend.requestee,
  );

  // get friend's subscribed topics
  const { data: friendTopicSubscriptions } = await serviceRoleSupabase
    .from(
      "topic_members",
    )
    .select("*, topic(id, name)")
    .eq("member", userId)
    .order("name", { referencedTable: "topic" })
    .throwOnError();

  // sort topics alphabetically because remote order doesn't work for some reason
  friendTopicSubscriptions!.sort((a, b) =>
    a.topic.name.localeCompare(b.topic.name)
  );

  // get current users overlapping topic subscriptions
  const { data: overlappingTopicSubscriptions } = await serviceRoleSupabase
    .from(
      "topic_members",
    )
    .select("topic")
    .eq("member", currentUser.id)
    .throwOnError();

  // build composite subscriptions list
  const mySubscriptions = new Set(
    overlappingTopicSubscriptions?.map((topicSubscription) =>
      topicSubscription.topic
    ),
  );

  const topicSubscriptions = friendTopicSubscriptions!.map((
    friendTopicSubscription,
  ) => ({
    topic: friendTopicSubscription.topic,
    subscribed: mySubscriptions.has(friendTopicSubscription.topic.id),
  }));

  // return new friend request
  return new Response(
    JSON.stringify({
      profile: scrubProfile(friendProfile),
      topic_subscriptions: topicSubscriptions,
    }),
    {
      headers: { "Content-Type": "application/json" },
      status: 200,
    },
  );
});
