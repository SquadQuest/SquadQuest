import { serve } from "../_shared/http.ts";
import {
  getAnonSupabaseClient,
  getServiceRoleSupabaseClient,
} from "../_shared/supabase.ts";

Deno.serve(async (request) => {
  // connect to Supabase
  const serviceRoleSupabase = getServiceRoleSupabaseClient();
  const anonSupabase = getAnonSupabaseClient(request);

  const headers: { [index: string]: string } = {};
  for (const [key, value] of request.headers.entries()) {
    headers[key] = value;
  }

  const authorizationHeaderRegexp =
    /^Bearer ([A-Za-z0-9_-]{2,}(?:\.[A-Za-z0-9_-]{2,}){2})$/;
  const authHeader = request.headers.get("Authorization");
  const token = authHeader?.replace(authorizationHeaderRegexp, "$1");

  return new Response(
    JSON.stringify({
      token,
      service_role: (await serviceRoleSupabase.rpc("get_current_role")).data,
      anon_role: (await anonSupabase.rpc("get_current_role")).data,
      topics: (await anonSupabase.from("topics").select("*")).data,
      request: {
        method: request.method,
        url: request.url,
        headers,
        body: request.body,
      },
    }),
    {
      headers: { "Content-Type": "application/json" },
      status: 200,
    },
  );
});
