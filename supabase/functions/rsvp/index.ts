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
  const { data: event } = await serviceRoleSupabase
    .from(
      "instances",
    )
    .select()
    .eq("id", instanceId)
    .maybeSingle()
    .throwOnError();

  if (!event) {
    throw new HttpError(
      "No event found matching that instance_id",
      404,
      "event-not-found",
    );
  }

  // get any existing RSVP/invite
  const { data: existingRsvp } = await serviceRoleSupabase.from(
    "instance_members",
  )
    .select()
    .eq("instance", instanceId)
    .eq("member", currentUser.id)
    .maybeSingle()
    .throwOnError();

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
      const { count: friendshipCount } = await serviceRoleSupabase.from(
        "friends",
      )
        .select("*", { count: "exact", head: true })
        .in("requester", [currentUser.id, event.created_by])
        .in("requestee", [currentUser.id, event.created_by])
        .throwOnError();

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
    const { data: deletedRsvp } = await serviceRoleSupabase.from(
      "instance_members",
    )
      .delete()
      .eq("id", existingRsvp.id)
      .select(defaultSelect)
      .single()
      .throwOnError();

    deletedRsvp.status = null;
    rsvp = deletedRsvp;

    notificationBody = `RSVP removed for {{userDisplayName}}`;
  } else if (existingRsvp) {
    // update existing RSVP
    const { data: updatedRsvp } = await serviceRoleSupabase.from(
      "instance_members",
    )
      .update({ status: status ?? "invited" })
      .eq("id", existingRsvp.id)
      .select(defaultSelect)
      .single()
      .throwOnError();

    rsvp = updatedRsvp;

    notificationBody = status == "invited"
      ? `RSVP removed for {{userDisplayName}}`
      : `RSVP ${status} (from ${existingRsvp.status}) for {{userDisplayName}}`;
  } else if (status) {
    // insert new RSVP
    const { data: insertedRsvp } = await serviceRoleSupabase.from(
      "instance_members",
    )
      .insert({
        created_by: currentUser.id, // must supply because we're running as service role
        instance: instanceId,
        member: currentUser.id,
        status: status,
      })
      .select(defaultSelect)
      .single()
      .throwOnError();

    rsvp = insertedRsvp;

    notificationBody = `RSVP ${status} for {{userDisplayName}}`;
  } else {
    // posting null status to an RSVP that doesn't exist is a no-op
  }

  // build list of profiles to notify
  const profilesToNotify = [];

  if (notificationBody) {
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
      .or(
        `requester.eq."${currentUser!.id}", requestee.eq."${currentUser!.id}"`,
      )
      .throwOnError();

    const friendIds = new Set();
    for (const friendship of friends!) {
      const friendId = friendship.requester == currentUser!.id
        ? friendship.requestee
        : friendship.requester;

      friendIds.add(friendId);
    }

    // send to host if they're not the one RSVPing
    if (event.created_by != currentUser.id) {
      profilesToNotify.push(
        await getSupabaseUserProfile(request, event.created_by),
      );
    }

    // send to other guests who are RSVP'd for OMWs
    if (status == "omw") {
      const { data: rsvps } = await serviceRoleSupabase
        .from(
          "instance_members",
        )
        .select("*, member(*)")
        .eq("instance", instanceId)
        .in("status", ["maybe", "yes", "omw"])
        .neq("member", currentUser.id)
        .neq("member", event.created_by)
        .in("id", Array.from(friendIds))
        .throwOnError();

      for (const rsvp of rsvps!) {
        profilesToNotify.push(rsvp.member);
      }
    }

    // send notification to all queued recipients
    for (const profile of profilesToNotify) {
      if (
        !profile.fcm_token ||
        !profile.enabled_notifications.includes(
          profile.id == event.created_by ? "guestRsvp" : "friendOnTheWay",
        )
      ) {
        continue;
      }

      try {
        const scrubbedProfile = await scrubProfile(
          rsvp.member,
          friendIds.has(profile.id),
        );

        const userDisplayName = scrubbedProfile.last_name
          ? `${scrubbedProfile.first_name} ${scrubbedProfile.last_name}`
          : `${scrubbedProfile.first_name}`;

        await postMessage({
          notificationType: "rsvp",
          token: profile.fcm_token,
          title: event.title,
          body: notificationBody.replace(
            "{{userDisplayName}}",
            userDisplayName,
          ),
          url: `https://squadquest.app/events/${event.id}`,
          payload: {
            event,
            rsvp: {
              ...rsvp,
              member: scrubbedProfile,
            },
          },
          collapseKey: "rsvp",
        });
      } catch (error) {
        console.error(error);
      }
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
