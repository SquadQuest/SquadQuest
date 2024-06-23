import {
  assert,
  assertPost,
  getRequiredJsonParameters,
  HttpError,
  serve,
} from "../_shared/http.ts";
import {
  getServiceRoleSupabaseClient,
  getSupabaseUser,
  getSupabaseUserProfile,
} from "../_shared/supabase.ts";
import { postMessage } from "../_shared/fcm.ts";
import { scrubProfile } from "../_shared/squadquest.ts";

serve(async (request) => {
  // process request
  assertPost(request);
  const { instance_id: instanceId, status } = await getRequiredJsonParameters(
    request,
    [
      "instance_id",
      "status",
    ],
  );

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

  // get event
  const { data: event, error: eventError } = await serviceRoleSupabase
    .from(
      "instances",
    )
    .select()
    .eq("id", instanceId)
    .maybeSingle();
  if (eventError) throw eventError;
  if (!event) {
    throw new HttpError(
      "No event found matching that instance_id",
      404,
      "event-not-found",
    );
  }

  // get any existing RSVP/invite
  const { data: existingRsvp, error: existingRsvpError } =
    await serviceRoleSupabase.from(
      "instance_members",
    )
      .select()
      .eq("instance", instanceId)
      .eq("member", currentUser.id)
      .maybeSingle();
  if (existingRsvpError) throw existingRsvpError;

  // verify user has access to event
  switch (event.visibility) {
    case "private":
      // only creater and those invited can RSVP
      assert(
        event.created_by == currentUser.id || existingRsvp,
        "This event is private and you were not invited yet",
        403,
        "not-invited",
      );
      break;
    case "friends": {
      // the creator and people invited can RSVP
      if (event.created_by == currentUser.id || existingRsvp) {
        break;
      }

      // friends can too
      const { count: friendshipCount, error: friendshipError } =
        await serviceRoleSupabase.from(
          "friends",
        )
          .select("*", { count: "exact", head: true })
          .in("requester", [currentUser.id, event.created_by])
          .in("requestee", [currentUser.id, event.created_by]);
      if (friendshipError) throw friendshipError;

      assert(
        friendshipCount! > 0,
        "This event is for friends only and you are not on the host's friends list",
        403,
        "not-invited-or-friends",
      );

      break;
    }
    case "public":
      // anyone can RSVP
  }

  // branch actions
  const defaultSelect = "*, member(*)";
  const userFullName =
    `${currentUser.user_metadata.first_name} ${currentUser.user_metadata.last_name}`;
  let rsvp;
  let notificationBody: string | null = null;

  if (existingRsvp && existingRsvp.status == (status ?? "invited")) {
    // no-op
    rsvp = existingRsvp;

    // enrich data
    rsvp.member = await getSupabaseUserProfile(request, rsvp.member.id);
  } else if (
    status == null && existingRsvp &&
    existingRsvp.created_by == currentUser.id
  ) {
    // delete RSVP if user created it and they're removing their RSVP
    const { data: deletedRsvp, error: deletedRsvpError } =
      await serviceRoleSupabase.from(
        "instance_members",
      )
        .delete()
        .eq("id", existingRsvp.id)
        .select(defaultSelect)
        .single();
    if (deletedRsvpError) throw deletedRsvpError;

    deletedRsvp.status = null;
    rsvp = deletedRsvp;

    notificationBody = `RSVP removed for ${userFullName}`;
  } else if (existingRsvp) {
    // update existing RSVP
    const { data: updatedRsvp, error: updatedRsvpError } =
      await serviceRoleSupabase.from(
        "instance_members",
      )
        .update({ status: status ?? "invited" })
        .eq("id", existingRsvp.id)
        .select(defaultSelect)
        .single();
    if (updatedRsvpError) throw updatedRsvpError;

    rsvp = updatedRsvp;

    notificationBody = status == "invited"
      ? `RSVP removed for ${userFullName}`
      : `RSVP ${status} (from ${existingRsvp.status}) for ${userFullName}`;
  } else if (status) {
    // insert new RSVP
    const { data: insertedRsvp, error: insertedRsvpError } =
      await serviceRoleSupabase.from(
        "instance_members",
      )
        .insert({
          created_by: currentUser.id, // must supply because we're running as service role
          instance: instanceId,
          member: currentUser.id,
          status: status,
        })
        .select(defaultSelect)
        .single();
    if (insertedRsvpError) throw insertedRsvpError;

    rsvp = insertedRsvp;

    notificationBody = `RSVP ${status} for ${userFullName}`;
  } else {
    // posting null status to an RSVP that doesn't exist is a no-op
  }

  // scrub profile data
  rsvp.member = scrubProfile(rsvp.member);

  // build list of profiles to notify
  const profilesToNotify = [];

  if (notificationBody) {
    // send to host if they're not the one RSVPing
    if (event.created_by != currentUser.id) {
      profilesToNotify.push(
        await getSupabaseUserProfile(request, event.created_by),
      );
    }

    // send to other guests who are RSVP'd for OMWs
    if (status == "omw") {
      const { data: rsvps, error: rsvpsError } = await serviceRoleSupabase
        .from(
          "instance_members",
        )
        .select("*, member(*)")
        .eq("instance", instanceId)
        .in("status", ["maybe", "yes", "omw"])
        .neq("member", currentUser.id)
        .neq("member", event.created_by);
      if (rsvpsError) throw rsvpsError;

      for (const rsvp of rsvps) {
        profilesToNotify.push(rsvp.member);
      }
    }

    // send notification to all queued recipients
    for (const profile of profilesToNotify) {
      if (!profile.fcm_token) {
        continue;
      }

      await postMessage({
        notificationType: "rsvp",
        token: profile.fcm_token,
        title: event.title,
        body: notificationBody,
        url: `https://squadquest.app/#/events/${event.id}`,
        payload: { event, rsvp },
        collapseKey: "rsvp",
      });
    }
  }

  // return new RSVP
  return new Response(
    rsvp ? JSON.stringify(rsvp) : null,
    {
      headers: { "Content-Type": "application/json" },
      status: rsvp ? 200 : 204,
    },
  );
});
