import { assertGet, HttpError, serve } from "../_shared/http.ts";
import { getAnonSupabaseClient, getSupabaseUser } from "../_shared/supabase.ts";

interface NetworkEntry {
  mutuals: Set<string>;
  first_name?: string;
  last_name?: string;
  photo?: string | null;
  trail_color?: string | null;
}

serve(async (request) => {
  console.log("handling request", request.url);

  // process request
  assertGet(request);

  // get current user
  const currentUser = await getSupabaseUser(request);
  if (!currentUser) {
    throw new HttpError(
      "Authorized user not found",
      403,
      "authorized-user-not-found",
    );
  }

  // connect to Supabase
  const userSupabase = getAnonSupabaseClient(request);

  // get friends network
  const { data: network } = await userSupabase
    .from("friends_network")
    .select("*")
    .throwOnError();
  console.log("got network", network?.length);

  // serialize maps and sets
  const networkEntries = network!.map(
    ({ id, profile, mutuals }) => (<NetworkEntry> {
      id,
      ...profile,
      mutuals,
    }),
  );

  // return friend network data
  return new Response(
    JSON.stringify(networkEntries),
    {
      headers: { "Content-Type": "application/json" },
      status: 200,
    },
  );
});
