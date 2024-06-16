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
  const { data: event, error: eventError } = await serviceRoleSupabase
    .from(
      "instances",
    )
    .select()
    .eq("id", instanceId)
    .maybeSingle();
  if (eventError) throw eventError;
  assert(
    event != null,
    "No event found matching that instance_id",
    404,
    "event-not-found",
  );

  // get any existing RSVPs
  const { data: existingRsvp, error: existingRsvpError } =
    await serviceRoleSupabase.from(
      "instance_members",
    )
      .select("member")
      .eq("instance", instanceId)
      .in("member", inviteUserIds);
  if (existingRsvpError) throw existingRsvpError;

  const existingRsvpUserIds = new Set(
    existingRsvp.map((rsvp) => rsvp.member),
  );

  // get list of user's friends
  const { data: friends, error: friendsError } = await serviceRoleSupabase
    .from(
      "friends",
    )
    .select("requester, requestee")
    .eq("status", "accepted")
    .or(`requester.eq."${currentUser!.id}", requestee.eq."${currentUser!.id}"`);
  if (friendsError) throw friendsError;

  const friendUserIds = new Set(
    friends.map((friend) =>
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
  const { data: insertedInvitations, error: insertedInvitationsError } =
    await serviceRoleSupabase.from(
      "instance_members",
    )
      .insert(invitations)
      .select("*, member(*)");
  if (insertedInvitationsError) throw insertedInvitationsError;

  // return new invitations
  return new Response(
    insertedInvitations.length ? JSON.stringify(insertedInvitations) : null,
    {
      headers: { "Content-Type": "application/json" },
      status: insertedInvitations.length ? 200 : 204,
    },
  );
});
