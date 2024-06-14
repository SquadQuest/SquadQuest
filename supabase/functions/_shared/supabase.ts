import {
  createClient,
  SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js";

import { HttpError } from "./http.ts";

function createServiceRoleSupabaseClient() {
  return createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    {
      global: {
        headers: {
          Authorization: `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`,
        },
      },
    },
  );
}

function createAnonSupabaseClient(request: Request) {
  return createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    {
      global: {
        headers: { Authorization: request.headers.get("Authorization")! },
      },
    },
  );
}

const authorizationHeaderRegexp =
  /^Bearer ([A-Za-z0-9_-]{2,}(?:\.[A-Za-z0-9_-]{2,}){2})$/;
async function getSupabaseUser(
  supabaseClient: SupabaseClient,
  request: Request,
) {
  const authHeader = request.headers.get("Authorization");

  if (authHeader == null) {
    throw new HttpError("Request missing required header: Authorization", 401);
  }

  if (!authorizationHeaderRegexp.test(authHeader)) {
    throw new HttpError(
      "Authorization header must be in the format 'Bearer {jwt}'",
      401,
    );
  }

  const token = authHeader.replace(authorizationHeaderRegexp, "$1");

  const { data } = await supabaseClient.auth.getUser(token);
  return data.user;
}

export {
  createAnonSupabaseClient,
  createServiceRoleSupabaseClient,
  getSupabaseUser,
};
