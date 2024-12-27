import {
  assertPost,
  getRequiredJsonParameters,
  HttpError,
  serve,
} from "../_shared/http.ts";
import {
  getServiceRoleSupabaseClient,
  getSupabaseUser,
} from "../_shared/supabase.ts";

serve(async (request) => {
  // process request
  assertPost(request);
  const { event_id: eventId, timestamp } = await getRequiredJsonParameters(
    request,
    [
      "event_id",
      "timestamp",
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

  // write to RSVPs title
  await serviceRoleSupabase.from("instance_members")
    .update({ chat_last_seen: timestamp })
    .eq("instance", eventId)
    .eq("member", currentUser.id)
    .single()
    .throwOnError();

  // return status
  return new Response(null, { status: 200 });
});
