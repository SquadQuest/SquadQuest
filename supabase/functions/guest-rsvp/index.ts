// guest-rsvp: lets a guest without a SquadQuest account see and answer the
// events an organizer added them to, through a private link (?t=<token>), or
// join one event through its open link (?o=<token>), e.g. from a flyer.
//
// No user login: the caller is identified only by the token. Runs everything
// as the service role, which is why every query below is scoped by the
// token's own guest or link. Contract and deploy notes: docs/guest-rsvp.md.
import { serve } from "../_shared/http.ts";
import { getServiceRoleSupabaseClient } from "../_shared/supabase.ts";
import {
  AnswerStatus,
  createHandler,
  GuestStatus,
  GuestStore,
  InstanceRow,
  OpenJoinResult,
} from "./handler.ts";

const INSTANCE_COLUMNS =
  "id,title,start_time_min,start_time_max,end_time,location_description,notes,banner_photo,status,created_by";

const supabase = getServiceRoleSupabaseClient();

const store: GuestStore = {
  async guestByToken(token) {
    const { data } = await supabase
      .from("guests")
      .select("id,name,host")
      .eq("token", token)
      .maybeSingle()
      .throwOnError();
    return data;
  },

  async hostFirstName(host) {
    const { data } = await supabase
      .from("profiles")
      .select("first_name")
      .eq("id", host)
      .maybeSingle()
      .throwOnError();
    return data?.first_name ?? null;
  },

  async guestEvents(guest) {
    const { data } = await supabase
      .from("instance_guests")
      .select(`status, instance(${INSTANCE_COLUMNS})`)
      .eq("guest", guest)
      .throwOnError();
    return (data ?? []).map((row) => ({
      instance: row.instance as unknown as InstanceRow,
      status: row.status as GuestStatus,
    }));
  },

  async setStatus(guest, instance, status: AnswerStatus) {
    const { data } = await supabase
      .from("instance_guests")
      .update({ status })
      .eq("guest", guest)
      .eq("instance", instance)
      .select("status")
      .throwOnError();
    return (data ?? []).length === 1;
  },

  async openLinkByToken(token) {
    const { data } = await supabase
      .from("instance_open_links")
      .select(`closed_at,max_guests,guests_created,instance(${INSTANCE_COLUMNS})`)
      .eq("token", token)
      .maybeSingle()
      .throwOnError();
    if (!data) return null;
    return {
      instance: data.instance as unknown as InstanceRow,
      closed_at: data.closed_at,
      max_guests: data.max_guests,
      guests_created: data.guests_created,
    };
  },

  async openJoin(token, name, phone, status): Promise<OpenJoinResult> {
    const { data, error } = await supabase.rpc("guest_rsvp_open_join", {
      p_token: token,
      p_name: name,
      p_phone: phone,
      p_status: status,
    });
    if (error) {
      // the database function raises one of these fixed messages
      if (["not_found", "conflict", "bad_request"].includes(error.message)) {
        return { error: error.message as "not_found" | "conflict" | "bad_request" };
      }
      throw new Error(`guest_rsvp_open_join failed: ${error.message}`);
    }
    return { token: data as string };
  },
};

serve(createHandler(store));
