import { assertPost, serve } from "../_shared/http.ts";
import { getServiceRoleSupabaseClient } from "../_shared/supabase.ts";
import { postMessage } from "../_shared/fcm.ts";

type Event = {
  id: string;
  title: string;
  created_by: string;
  status: string;
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

  // skip rest of function if status hasn't been modified
  if (!oldEvent || event.status == oldEvent.status) {
    return new Response(
      JSON.stringify({ success: true, event }),
      {
        headers: { "Content-Type": "application/json" },
        status: 304,
      },
    );
  }

  // skip if event hasn't been set to canceled / uncanceled
  if (event.status != "canceled" && oldEvent.status != "canceled") {
    return new Response(
      JSON.stringify({ success: true, event }),
      {
        headers: { "Content-Type": "application/json" },
        status: 204,
      },
    );
  }

  // connect to Supabase
  const serviceRoleSupabase = getServiceRoleSupabaseClient();

  // get RSVPs to all maybe/yes/omw RSVPs but creator
  const { data: rsvps } = await serviceRoleSupabase.from(
    "instance_members",
  )
    .select("*, member(*)")
    .eq("instance", event.id)
    .neq("member", event.created_by)
    .in("status", ["maybe", "yes", "omw"])
    .throwOnError();

  // send notification to all queued recipients
  for (const { member: profile } of rsvps!) {
    if (
      !profile.fcm_token ||
      !profile.enabled_notifications_v2.includes("eventChange")
    ) {
      continue;
    }

    try {
      await postMessage({
        notificationType: event.status == "canceled"
          ? "event-canceled"
          : "event-uncanceled",
        token: profile.fcm_token,
        title: event.title,
        body: event.status == "canceled"
          ? "Event canceled"
          : "Event uncanceled",
        url: `https://squadquest.app/events/${event.id}`,
        payload: { event },
        collapseKey: event.status == "canceled"
          ? "event-canceled"
          : "event-uncanceled",
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
