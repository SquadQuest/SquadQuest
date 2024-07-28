import { assertPost, serve } from "../_shared/http.ts";
import { getServiceRoleSupabaseClient } from "../_shared/supabase.ts";

type Profile = {
  id: string;
  phone: string;
  first_name: string;
  last_name: string;
};

type WebhookPayload = {
  type: "INSERT";
  table: "profiles";
  schema: "public";
  record: Profile;
  old_record: null;
};

serve(async (request) => {
  // process request
  assertPost(request);
  const { record: profile }: WebhookPayload = await request.json();

  // connect to Supabase
  const serviceRoleSupabase = getServiceRoleSupabaseClient();

  // get user data
  const { data: { user: authUserData }, error: authUserError } =
    await serviceRoleSupabase
      .auth.admin.getUserById(profile.id);
  if (authUserError) throw authUserError;

  // automatically insert friend requests
  if (authUserData?.app_metadata.invite_friends) {
    await serviceRoleSupabase.from("friends")
      .upsert(
        authUserData?.app_metadata.invite_friends.map((requester: string) => ({
          requester: requester,
          requestee: profile.id,
          status: "requested",
        })),
      )
      .throwOnError();
  }

  // return event
  return new Response(
    JSON.stringify({ success: true }),
    {
      headers: { "Content-Type": "application/json" },
      status: 200,
    },
  );
});
