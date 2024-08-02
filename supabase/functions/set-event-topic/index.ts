import { assertPost, serve } from "../_shared/http.ts";
import { getServiceRoleSupabaseClient } from "../_shared/supabase.ts";
import { postMessage } from "../_shared/fcm.ts";

type Event = {
  id: string;
  title: string;
  created_by: string;
  status: string;
  visibility: string;
  topic: string;
};

type WebhookPayload = {
  type: "INSERT" | "UPDATE";
  table: "instances";
  schema: "public";
  record: Event;
  old_record: Event;
};

serve(async (request) => {
  // process request
  assertPost(request);
  const { record: event, old_record: oldEvent }: WebhookPayload = await request
    .json();

  // skip rest of function if topic hasn't been modified
  if (oldEvent && event.topic == oldEvent.topic) {
    return new Response(
      JSON.stringify({ success: true, event }),
      {
        headers: { "Content-Type": "application/json" },
        status: 304,
      },
    );
  }

  // skip if event is private or isn't live
  if (event.visibility == "private" || event.status != "live") {
    return new Response(
      JSON.stringify({ success: true, event }),
      {
        headers: { "Content-Type": "application/json" },
        status: 204,
      },
    );
  }

  // TODO: skip if event is "over"

  // connect to Supabase
  const serviceRoleSupabase = getServiceRoleSupabaseClient();

  // get topic
  const { data: topic } = await serviceRoleSupabase.from("topics").select().eq(
    "id",
    event.topic,
  ).single();

  // get all existing RSVPs
  const { data: rsvps } = await serviceRoleSupabase.from(
    "instance_members",
  )
    .select("member")
    .eq("instance", event.id)
    .throwOnError();

  const rsvpUserIds = rsvps?.map((rsvp) => rsvp.member);

  // build topic members query
  const notifyUsersQuery = serviceRoleSupabase.from("topic_members").select(
    "member!inner(id, fcm_token, enabled_notifications)",
  ).eq("topic", topic.id)
    .not("member", "in", `("${rsvpUserIds?.join('","')}")`)
    .not("member.fcm_token", "is", null)
    .filter(
      "member.enabled_notifications",
      "cs",
      event.visibility == "public"
        ? '{"publicEventPosted"}'
        : '{"friendsEventPosted"}',
    );

  // add filter down to creator's friends
  if (event.visibility == "friends") {
    const { data: friends } = await serviceRoleSupabase
      .from(
        "friends",
      )
      .select("requester, requestee")
      .eq("status", "accepted")
      .or(
        `requester.eq."${event.created_by}", requestee.eq."${event.created_by}"`,
      )
      .throwOnError();

    const friendUserIds = new Set(
      friends!.map((friend) =>
        friend.requester == event.created_by
          ? friend.requestee
          : friend.requester
      ),
    );

    notifyUsersQuery.in("member", Array.from(friendUserIds));
  }

  // get notification targets
  const { data: notifyUsers } = await notifyUsersQuery.throwOnError();

  console.log(
    `Sending notifications for event ${event.title} to ${
      notifyUsers!.length
    } users subscribed to topic ${topic.name}`,
  );

  // send notification to all queued recipients
  for (const { member: profile } of notifyUsers!) {
    console.log(
      `Sending to ${profile.id}: ${
        event.visibility == "public" ? "Public" : "Friends-only"
      } event posted to ${topic.name}`,
    );
    try {
      await postMessage({
        notificationType: "event-posted",
        token: profile.fcm_token,
        title: event.title,
        body: `${
          event.visibility == "public" ? "Public" : "Friends-only"
        } event posted to ${topic.name}`,
        url: `https://squadquest.app/events/${event.id}`,
        payload: { event },
        collapseKey: "event-posted",
      });
    } catch (error) {
      console.error(error);
      // continue with next recipient
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
