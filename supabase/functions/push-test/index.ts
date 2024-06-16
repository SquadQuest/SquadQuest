import { serve } from "../_shared/http.ts";
import { getSupabaseUserProfile } from "../_shared/supabase.ts";
import { postMessage } from "../_shared/fcm.ts";

interface WebhookPayload {
  type: "INSERT";
  table: string;
  record: {
    id: string;
    user_id: string;
    body: string;
  };
  schema: "public";
}

serve(async (request) => {
  const payload: WebhookPayload = await request.json();
  const userProfile = await getSupabaseUserProfile(request);
  const fcmToken = userProfile!.fcm_token as string;

  if (fcmToken == null) {
    return new Response("FCM token is not found", { status: 400 });
  }

  const responseData = await postMessage({
    token: fcmToken,
    notification: {
      title: `Notification from Supabase`,
      body: payload.record.body,
    },
    data: { hello: "world" },
  });

  return new Response(JSON.stringify(responseData), {
    headers: { "Content-Type": "application/json" },
  });
});
