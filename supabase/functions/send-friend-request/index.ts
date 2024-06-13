import {
  createAnonSupabaseClient,
  createServiceRoleSupabaseClient,
  getSupabaseUser,
} from "../_shared/supabase.ts";
import {
  assertPost,
  getRequiredJsonParameters,
  HttpError,
} from "../_shared/http.ts";

Deno.serve(async (request) => {
  try {
    // process request
    assertPost(request);
    const { phone } = await getRequiredJsonParameters(request, [
      "phone",
    ]);

    // connect to Supabase
    const serviceRoleSupabase = createServiceRoleSupabaseClient();
    const anonSupabase = createAnonSupabaseClient(request);

    // get requesting user
    const currentUser = await getSupabaseUser(anonSupabase, request);
    if (!currentUser) {
      throw new HttpError(
        "Authorized user not found",
        403,
        "authorized-user-not-found",
      );
    }

    // get requestee user
    const { data: requesteeUser, error: requesteeError } =
      await serviceRoleSupabase.from(
        "profiles",
      )
        .select("*")
        .eq("phone", phone)
        .maybeSingle();
    if (requesteeError) throw requesteeError;
    if (!requesteeUser) {
      throw new HttpError(
        "No profile found matching that phone number, ask them to sign up first",
        404,
        "requestee-not-found",
      );
    }

    // prevent friending yourself
    if (requesteeUser.id == currentUser.id) {
      throw new HttpError(
        "You can't be friends with yourself",
        400,
        "self-friending",
      );
    }

    // check that no link exists already in either direction
    const { count: existingFriendsCount, error: existingFriendsError } =
      await serviceRoleSupabase.from(
        "friends",
      )
        .select("*", { count: "exact", head: true })
        .in("requester", [currentUser.id, requesteeUser.id])
        .in("requestee", [currentUser.id, requesteeUser.id]);
    if (existingFriendsError) throw existingFriendsError;
    if (existingFriendsCount! > 0) {
      throw new HttpError(
        "A matching friend connection already exists for that phone number",
        400,
        "friend-exists",
      );
    }

    // insert friend request
    const { data: newFriendRequest, error: insertError } =
      await serviceRoleSupabase.from("friends")
        .insert({
          requester: currentUser.id,
          requestee: requesteeUser.id,
          status: "requested",
        })
        .select("*, requester(*), requestee(*)")
        .single();
    if (insertError) throw insertError;

    // return new friend request
    return new Response(
      JSON.stringify(newFriendRequest),
      {
        headers: { "Content-Type": "application/json" },
        status: 200,
      },
    );
  } catch (error) {
    if (error instanceof HttpError) {
      let message = error.message;

      if (error.errorId) {
        message = `${error.errorId}: ${message}`;
      }

      return new Response(
        message,
        {
          status: error.code,
        },
      );
    }

    return new Response(
      JSON.stringify({
        message: String(error?.message ?? error),
        error_id: error.errorId,
      }),
      {
        headers: { "Content-Type": "application/json" },
        status: 500,
      },
    );
  }
});
