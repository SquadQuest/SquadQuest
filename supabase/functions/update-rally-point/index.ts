import { assertPost, serve } from "../_shared/http.ts";
import { getServiceRoleSupabaseClient } from "../_shared/supabase.ts";
import { postMessage } from "../_shared/fcm.ts";

type Event = {
  id: string;
  title: string;
  created_by: string;
  rally_point: string;
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
  const { record: event }: WebhookPayload = await request.json();

  // connect to Supabase
  const serviceRoleSupabase = getServiceRoleSupabaseClient();

  // get RSVPs to all yes/maybe RSVPs but creator
  const { data: rsvps, error: rsvpsError } = await serviceRoleSupabase.from(
    "instance_members",
  )
    .select("*, member(*)")
    .eq("instance", event.id)
    .neq("member", event.created_by)
    .in("status", ["yes", "omw"]);
  if (rsvpsError) throw rsvpsError;

  // send notification to all queued recipients
  for (const { member: profile } of rsvps) {
    if (!profile.fcm_token) {
      continue;
    }

    await postMessage({
      notificationType: "rally-point-updated",
      token: profile.fcm_token,
      title: event.title,
      body: `Rally point ${event.rally_point ? "updated" : "cleared"}`,
      url: `https://squadquest.app/#/events/${event.id}`,
      payload: { event },
      collapseKey: "rally-point-updated",
    });
  }

  // return new friend request
  return new Response(
    JSON.stringify({ success: true, event }),
    {
      headers: { "Content-Type": "application/json" },
      status: 200,
    },
  );
});
