import {
  assertGet,
  getRequiredQueryParameters,
  HttpError,
  serve,
} from "../_shared/http.ts";
import {
  getServiceRoleSupabaseClient,
  getSupabaseUser,
} from "../_shared/supabase.ts";
import { normalizePhone, scrubProfile } from "../_shared/squadquest.ts";

serve(async (request) => {
  // process request
  assertGet(request);
  const { phone: rawPhone } = await getRequiredQueryParameters(request, [
    "phone",
  ]);

  const phone = normalizePhone(rawPhone);

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

  // get requestee user
  const { data: existingProfile } = await serviceRoleSupabase.from(
    "profiles",
  )
    .select("*")
    .eq("phone", phone)
    .maybeSingle()
    .throwOnError();

  // return null if no profile found
  if (!existingProfile) {
    // check if an invitation already exists
    const { data: existingAuthUser } = await serviceRoleSupabase.from(
      "auth_users",
    )
      .select("*")
      .eq("phone", phone)
      .maybeSingle()
      .throwOnError();

    return new Response(
      JSON.stringify({ profile: null, invited: Boolean(existingAuthUser) }),
      {
        headers: { "Content-Type": "application/json" },
        status: 200,
      },
    );
  }

  // return new friend request
  return new Response(
    JSON.stringify({
      profile: await scrubProfile(existingProfile, false),
      invited: null,
    }),
    {
      headers: { "Content-Type": "application/json" },
      status: 200,
    },
  );
});
