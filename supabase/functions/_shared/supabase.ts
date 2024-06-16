import {
  createClient,
  SupabaseClient,
  User,
} from "https://esm.sh/@supabase/supabase-js";

import { HttpError } from "./http.ts";

let serviceRoleSupabaseClient: SupabaseClient | null;
function getServiceRoleSupabaseClient() {
  if (serviceRoleSupabaseClient) return serviceRoleSupabaseClient;

  return serviceRoleSupabaseClient = createClient(
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

let anonSupabaseClient: SupabaseClient | null;
function getAnonSupabaseClient(request: Request) {
  if (anonSupabaseClient) return anonSupabaseClient;

  return anonSupabaseClient = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    {
      global: {
        headers: { Authorization: request.headers.get("Authorization")! },
      },
    },
  );
}

let supabaseUser: User | null;

const authorizationHeaderRegexp =
  /^Bearer ([A-Za-z0-9_-]{2,}(?:\.[A-Za-z0-9_-]{2,}){2})$/;

async function getSupabaseUser(
  request: Request,
) {
  if (supabaseUser) return supabaseUser;

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

  const { data } = await getAnonSupabaseClient(request).auth.getUser(token);
  return supabaseUser = data.user;
}

async function getSupabaseUserProfile(
  request: Request,
  userId?: string | null,
) {
  const { data, error } = await getAnonSupabaseClient(request)
    .from("profiles")
    .select("*")
    .eq("id", userId ?? (await getSupabaseUser(request))!.id)
    .single();

  if (error) {
    throw new HttpError(`Error getting user profile: ${error.message}`, 500);
  }

  return data;
}

export {
  getAnonSupabaseClient,
  getServiceRoleSupabaseClient,
  getSupabaseUser,
  getSupabaseUserProfile,
};
