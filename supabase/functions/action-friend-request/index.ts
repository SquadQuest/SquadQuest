import {
  assertPost,
  getRequiredJsonParameters,
  HttpError,
  serve,
} from "../_shared/http.ts";
import {
  getServiceRoleSupabaseClient,
  getSupabaseUser,
} from "../_shared/supabase.ts";
import { postMessage } from "../_shared/fcm.ts";
import { scrubProfile } from "../_shared/squadquest.ts";

serve(async (request) => {
  // process request
  assertPost(request);
  const { friend_id: friendId, action } = await getRequiredJsonParameters(
    request,
    [
      "friend_id",
      "action",
    ],
  );

  if (action != "accepted" && action != "declined") {
    throw new HttpError(
      "Action can only be one of: accept, decline",
      400,
      "invalid-action",
    );
  }

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
    .eq("id", friendId)
    .maybeSingle()
    .throwOnError();

  if (!friend) {
    throw new HttpError(
      "No friend request found matching that id",
      404,
      "friend-not-found",
    );
  }

  // only allow action on requested status
  if (friend.status != "requested") {
    throw new HttpError(
      "Friend is not in requested status",
      400,
      "not-requested-status",
    );
  }

  // update friend request
  const { data: updatedFriendRequest } = await serviceRoleSupabase.from(
    "friends",
  )
    .update({
      status: action,
      actioned_at: new Date(),
    })
    .eq("id", friend.id)
    .select("*, requester(*), requestee(*)")
    .single()
    .throwOnError();

  // scrub profile data
  const fcmToken = updatedFriendRequest.requester.fcm_token;
  updatedFriendRequest.requester = scrubProfile(updatedFriendRequest.requester);
  updatedFriendRequest.requestee = scrubProfile(updatedFriendRequest.requestee);

  // send notification to sender (if accepted)
  if (fcmToken && action == "accepted") {
    await postMessage({
      notificationType: "friend-request-accepted",
      token: fcmToken,
      title: "Friend request accepted!",
      body:
        `${updatedFriendRequest.requestee.first_name} ${updatedFriendRequest.requestee.last_name} is now your friend`,
      url: `https://squadquest.app/#/friends`,
      payload: { friendship: updatedFriendRequest },
      collapseKey: "friend-request-accepted",
    });
  }

  // return new friend request
  return new Response(
    JSON.stringify(updatedFriendRequest),
    {
      headers: { "Content-Type": "application/json" },
      status: 200,
    },
  );
});
