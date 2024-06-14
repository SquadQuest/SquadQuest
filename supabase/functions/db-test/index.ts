import {
  createAnonSupabaseClient,
  createServiceRoleSupabaseClient,
} from "../_shared/supabase.ts";

Deno.serve(async (request) => {
  try {
    // connect to Supabase
    const serviceRoleSupabase = createServiceRoleSupabaseClient();
    const anonSupabase = createAnonSupabaseClient(request);

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
  } catch (err) {
    return new Response(String(err?.message ?? err), { status: 500 });
  }
});
