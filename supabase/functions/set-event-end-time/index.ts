import { assertPost, serve } from "../_shared/http.ts";
import { getServiceRoleSupabaseClient } from "../_shared/supabase.ts";
import { postMessage } from "../_shared/fcm.ts";

type Event = {
  id: string;
  title: string;
  created_by: string;
  end_time: string;
};

type WebhookPayload = {
  type: "UPDATE";
  table: string;
  schema: string;
  record: Event;
  old_record: Event;
};

serve(async (request) => {
  // process request
  assertPost(request);
  const { record: event, old_record: oldEvent }: WebhookPayload = await request
    .json();

  // skip rest of function if end_time hasn't been modified
  if (!oldEvent || !event.end_time || event.end_time == oldEvent.end_time) {
    return new Response(
      JSON.stringify({ success: true, event }),
      {
        headers: { "Content-Type": "application/json" },
        status: 304,
      },
    );
  }

  // connect to Supabase
  const serviceRoleSupabase = getServiceRoleSupabaseClient();

  // get all users with location points
  const { data: locationUserIds } = await serviceRoleSupabase
    .rpc("get_users_with_location_points", { "for_event": event.id });

  // get RSVPs to all maybe/yes/omw RSVPs
  const { data: rsvps } = await serviceRoleSupabase.from(
    "instance_members",
  )
    .select("member")
    .eq("instance", event.id)
    .in("status", ["maybe", "yes", "omw"])
    .throwOnError();

  // build unique set
  const userIds = new Set([
    ...locationUserIds,
    ...rsvps!.map((rsvp) => rsvp.member),
  ]);

  // get full profiles
  const { data: profiles } = await serviceRoleSupabase.from(
    "profiles",
  )
    .select("*")
    .in("id", Array.from(userIds))
    .throwOnError();

  // send notification to all queued recipients
  for (const profile of profiles!) {
    if (
      !profile.fcm_token ||
      !profile.enabled_notifications_v2.includes("eventChange")
    ) {
      continue;
    }

    try {
      await postMessage({
        notificationType: "event-ended",
        token: profile.fcm_token,
        title: event.title,
        body: `Event ended`,
        payload: { event },
      });
    } catch (error) {
      console.error(error);
    }
  }

  // return event
  return new Response(
    JSON.stringify({ success: true, event }),
    {
      headers: { "Content-Type": "application/json" },
      status: 200,
    },
  );
});
