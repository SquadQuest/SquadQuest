import {
  assert,
  assertPost,
  getRequiredJsonParameters,
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
  const { instance_id: instanceId, users: inviteUserIds } =
    await getRequiredJsonParameters(request, [
      "instance_id",
      "users",
    ]);
  assert(
    Array.isArray(inviteUserIds),
    `Parameter 'users' must be an array of UUIDs`,
  );

  // connect to Supabase
  const serviceRoleSupabase = getServiceRoleSupabaseClient();

  // get requesting user
  const currentUser = await getSupabaseUser(request);
  assert(
    currentUser != null,
    "Authorized user not found",
    403,
    "authorized-user-not-found",
  );

  // get event
  const { data: event } = await serviceRoleSupabase
    .from(
      "instances",
    )
    .select()
    .eq("id", instanceId)
    .maybeSingle()
    .throwOnError();

  assert(
    event != null,
    "No event found matching that instance_id",
    404,
    "event-not-found",
  );

  // get any existing RSVPs
  const { data: existingRsvp } = await serviceRoleSupabase.from(
    "instance_members",
  )
    .select("member")
    .eq("instance", instanceId)
    .in("member", inviteUserIds)
    .throwOnError();

  const existingRsvpUserIds = new Set(
    existingRsvp!.map((rsvp) => rsvp.member),
  );

  // TODO: check that user has permission to invite to this event

  // get list of user's friends
  const { data: friends } = await serviceRoleSupabase
    .from(
      "friends",
    )
    .select("requester, requestee")
    .eq("status", "accepted")
    .or(`requester.eq."${currentUser!.id}", requestee.eq."${currentUser!.id}"`)
    .throwOnError();

  const friendUserIds = new Set(
    friends!.map((friend) =>
      friend.requester == currentUser!.id ? friend.requestee : friend.requester
    ),
  );

  // create invitation for each user
  const invitations = [];
  for (const inviteUserId of inviteUserIds) {
    // skip if any record exists already
    if (existingRsvpUserIds.has(inviteUserId)) {
      continue;
    }

    // error if not a friend
    assert(
      friendUserIds.has(inviteUserId),
      "You can only send invitations to people you have a friend connection with",
      400,
      "invitee-not-friend",
    );

    invitations.push({
      created_by: currentUser!.id,
      instance: event.id,
      member: inviteUserId,
      status: "invited",
    });
  }

  // insert invitations
  const { data: insertedInvitations } = await serviceRoleSupabase.from(
    "instance_members",
  )
    .insert(invitations)
    .select("*, created_by(*), member(*)")
    .throwOnError();

  // send notifications to recipients
  for (const insertedInvitation of insertedInvitations!) {
    // scrub profile data
    const fcmToken = insertedInvitation.member.fcm_token;
    const notificationEnabled = insertedInvitation.member
      .enabled_notifications
      .includes("eventInvitation");
    insertedInvitation.created_by = scrubProfile(insertedInvitation.created_by);
    insertedInvitation.member = scrubProfile(insertedInvitation.member);

    if (fcmToken && notificationEnabled) {
      try {
        await postMessage({
          notificationType: "invitation",
          token: fcmToken,
          title: event.title,
          body:
            `${insertedInvitation.created_by.first_name} ${insertedInvitation.created_by.last_name} has invited you!`,
          url: `https://squadquest.app/events/${event.id}`,
          payload: { invitation: insertedInvitation },
          collapseKey: "invitation",
        });
      } catch (error) {
        console.error(error);
        // continue with next invitee
      }
    }
  }

  // return new invitations
  return new Response(
    insertedInvitations!.length ? JSON.stringify(insertedInvitations) : null,
    {
      headers: { "Content-Type": "application/json" },
      status: insertedInvitations!.length ? 200 : 204,
    },
  );
});
