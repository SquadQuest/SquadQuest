import { assertPost, serve } from "../_shared/http.ts";
import {
  getServiceRoleSupabaseClient,
  getSupabaseUserProfile,
} from "../_shared/supabase.ts";
import { scrubProfile } from "../_shared/squadquest.ts";
import { postMessage } from "../_shared/fcm.ts";

const maxMessageLength = 140;

type EventMessage = {
  id: string;
  created_by: string;
  instance: string;
  content: string;
};

type WebhookPayload = {
  type: "INSERT";
  schema: "public";
  table: "event_messages";
  record: EventMessage;
  old_record: EventMessage;
};

serve(async (request) => {
  // process request
  assertPost(request);
  const { record: eventMessage }: WebhookPayload = await request
    .json();

  // connect to Supabase
  const serviceRoleSupabase = getServiceRoleSupabaseClient();

  // get event
  const { data: event } = await serviceRoleSupabase
    .from("instances")
    .select("title")
    .eq("id", eventMessage.instance)
    .single()
    .throwOnError();

  // get sender's profile
  const { data: senderProfile } = await serviceRoleSupabase
    .from("profiles")
    .select()
    .eq("id", eventMessage.created_by)
    .single()
    .throwOnError();

  // get sender's friends
  const { data: senderFriends } = await serviceRoleSupabase
    .from(
      "friends",
    )
    .select("requester, requestee")
    .or(
      `status.eq."accepted",and(status.eq."requested", requestee.eq."${senderProfile.id}")`,
    )
    .or(
      `requester.eq."${senderProfile.id}", requestee.eq."${senderProfile.id}"`,
    )
    .throwOnError();

  const senderFriendIds = new Set();
  for (const friendship of senderFriends!) {
    const friendId = friendship.requester == senderProfile.id
      ? friendship.requestee
      : friendship.requester;

    senderFriendIds.add(friendId);
  }

  // get RSVPs to all maybe/yes/omw RSVPs
  const { data: rsvps } = await serviceRoleSupabase.from(
    "instance_members",
  )
    .select("*, member(*)")
    .eq("instance", eventMessage.instance)
    .neq("member", eventMessage.created_by)
    .in("status", ["maybe", "yes", "omw"])
    .throwOnError();

  // truncate message
  const truncatedMessage = eventMessage.content.length <= maxMessageLength
    ? eventMessage.content
    : `${eventMessage.content.substring, 0, maxMessageLength}…`;

  // send notification to all queued recipients
  for (const { member: profile } of rsvps!) {
    if (
      !profile.fcm_token ||
      !profile.enabled_notifications_v2.includes("eventMessage")
    ) {
      continue;
    }

    const scrubbedProfile = await scrubProfile(
      senderProfile,
      senderFriendIds.has(profile.id),
    );

    const userDisplayName = scrubbedProfile.last_name
      ? `${scrubbedProfile.first_name} ${scrubbedProfile.last_name}`
      : `${scrubbedProfile.first_name}`;

    await postMessage({
      notificationType: "event-message",
      token: profile.fcm_token,
      title: event!.title,
      body: `${userDisplayName}: ${truncatedMessage}`,
      url: `https://squadquest.app/events/${eventMessage.instance}`,
      payload: { eventMessage },
      collapseKey: `event-message-${eventMessage.instance}`,
    });
  }

  // return event
  return new Response(
    JSON.stringify({ success: true, eventMessage }),
    {
      headers: { "Content-Type": "application/json" },
      status: 200,
    },
  );
});
