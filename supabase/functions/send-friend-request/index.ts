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
import { sendSMS } from "../_shared/twilio.ts";
import { normalizePhone, scrubProfile } from "../_shared/squadquest.ts";

serve(async (request) => {
  // process request
  assertPost(request);
  const { phone: rawPhone, first_name: firstName, last_name: lastName } =
    await getRequiredJsonParameters(request, [
      "phone",
    ]);

  const phone = normalizePhone(rawPhone);

  // connect to Supabase
  const serviceRoleSupabase = getServiceRoleSupabaseClient();

  // get requesting user
  const currentUser = await getSupabaseUser(request);
  if (!currentUser) {
    throw new HttpError(
      "Authorized user not found",
      403,
      "authorized-user-not-found",
    );
  }

  // get requestee user
  let { data: requesteeUser } = await serviceRoleSupabase.from(
    "profiles",
  )
    .select("*")
    .eq("phone", phone)
    .maybeSingle()
    .throwOnError();

  // handle inviting a new user
  if (!requesteeUser) {
    // get full profile for current user
    const { data: currentUserProfile } = await serviceRoleSupabase.from(
      "profiles",
    )
      .select("*")
      .eq("id", currentUser.id)
      .single()
      .throwOnError();

    // check if invited user exists already
    const { data: existingAuthUser } = await serviceRoleSupabase.from(
      "auth_users",
    )
      .select("*")
      .eq("phone", phone)
      .maybeSingle()
      .throwOnError();

    // send SMS to new user
    const smsSent = await sendSMS(
      phone,
      `Hi, ${currentUserProfile.first_name} ${currentUserProfile.last_name} wants to be your friend on SquadQuest! ` +
        "Download the app at https://squadquest.app",
    );

    if (!smsSent) {
      throw new HttpError(
        "Failed to send SMS to new user, check the number",
        400,
        "sms-failed",
      );
    }

    // create or update existing auth user
    if (existingAuthUser) {
      const inviteFriends = new Set(existingAuthUser.invite_friends);
      inviteFriends.add(currentUser.id);

      serviceRoleSupabase.auth.admin.updateUserById(existingAuthUser.id, {
        app_metadata: { invite_friends: Array.from(inviteFriends) },
      }).then(console.log);
    } else {
      const { error: createUserError } = await serviceRoleSupabase.auth.admin
        .createUser({
          phone: phone,
          user_metadata: { first_name: firstName, last_name: lastName },
          app_metadata: { invite_friends: [currentUser.id] },
        });

      if (createUserError) throw createUserError;
    }

    return new Response(
      JSON.stringify({ invited: true }),
      {
        headers: { "Content-Type": "application/json" },
        status: 200,
      },
    );
  }

  // prevent friending yourself
  if (requesteeUser.id == currentUser.id) {
    throw new HttpError(
      "You can't be friends with yourself",
      400,
      "self-friending",
    );
  }

  // check that no link exists already in either direction
  const { count: existingFriendsCount } = await serviceRoleSupabase.from(
    "friends",
  )
    .select("*", { count: "exact", head: true })
    .in("requester", [currentUser.id, requesteeUser.id])
    .in("requestee", [currentUser.id, requesteeUser.id])
    .throwOnError();

  if (existingFriendsCount! > 0) {
    throw new HttpError(
      "A matching friend connection already exists for that phone number",
      400,
      "friend-exists",
    );
  }

  // insert friend request
  const { data: newFriendRequest } = await serviceRoleSupabase.from("friends")
    .insert({
      requester: currentUser.id,
      requestee: requesteeUser.id,
      status: "requested",
    })
    .select("*, requester(*), requestee(*)")
    .single()
    .throwOnError();

  // scrub profile data
  const fcmToken = newFriendRequest.requestee.fcm_token;
  newFriendRequest.requester = scrubProfile(newFriendRequest.requester);
  newFriendRequest.requestee = scrubProfile(newFriendRequest.requestee);

  // send notification to recipient
  if (fcmToken) {
    try {
      await postMessage({
        notificationType: "friend-request-received",
        token: fcmToken,
        title: "New friend request!",
        body:
          `${newFriendRequest.requester.first_name} ${newFriendRequest.requester.last_name} wants to be your friend`,
        url: `https://squadquest.app/friends`,
        payload: { friendship: newFriendRequest },
        collapseKey: "friend-request-received",
      });
    } catch (error) {
      console.error(error);
    }
  }

  // return new friend request
  return new Response(
    JSON.stringify(newFriendRequest),
    {
      headers: { "Content-Type": "application/json" },
      status: 200,
    },
  );
});
