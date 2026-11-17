// guest-rsvp: lets a guest without a SquadQuest account see and answer the
// events an organizer added them to, through a private link (?t=<token>), or
// answer one event by phone through its open link (?o=<token>), e.g. from a
// QR code on a flyer.
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
      .select("id,name,host,claimed_at")
      .eq("token", token)
      .maybeSingle()
      .throwOnError();
    if (!data) return null;
    return { id: data.id, name: data.name, host: data.host, claimed: data.claimed_at !== null };
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
      .select(`status, note, plus, instance(${INSTANCE_COLUMNS})`)
      .eq("guest", guest)
      .throwOnError();
    return (data ?? []).map((row) => ({
      instance: row.instance as unknown as InstanceRow,
      status: row.status as GuestStatus,
      note: (row.note as string | null) ?? null,
      plus: (row.plus as number | null) ?? 0,
    }));
  },

  async setAnswer(guest, instance, status: AnswerStatus, note, plus) {
    // tables/instance_rsvp_plus.sql: false when the guest is not on the
    // event, or when raising plus-ones would take the open link that
    // created the guest over its cap
    const { data } = await supabase
      .rpc("guest_rsvp_answer", {
        p_guest: guest,
        p_instance: instance,
        p_status: status,
        p_note: note ?? null,
        p_set_note: note !== undefined,
        p_plus: plus ?? null,
        p_set_plus: plus !== undefined,
      })
      .throwOnError();
    return data === true;
  },

  async phoneClaimed(host, phone) {
    const { data } = await supabase
      .from("guests")
      .select("claimed_at")
      .eq("host", host)
      .eq("phone", phone)
      .maybeSingle()
      .throwOnError();
    return data != null && data.claimed_at !== null;
  },

  async openLinkByToken(token) {
    const { data } = await supabase
      .from("instance_open_links")
      .select(`closed_at,max_guests,guests_created,instance(${INSTANCE_COLUMNS})`)
      .eq("token", token)
      .maybeSingle()
      .throwOnError();
    if (!data) return null;
    const { data: plusHeld } = await supabase
      .rpc("guest_open_link_plus", { p_token: token })
      .throwOnError();
    return {
      instance: data.instance as unknown as InstanceRow,
      closed_at: data.closed_at,
      max_guests: data.max_guests,
      guests_created: data.guests_created,
      plus_held: (plusHeld as number | null) ?? 0,
    };
  },

  async openJoin(token, name, phone, status, note, plus): Promise<OpenJoinResult> {
    // tables/instance_rsvp_plus.sql: p_set_note / p_set_plus false leave the
    // stored note / plus-ones as they are
    const { data, error } = await supabase.rpc("guest_rsvp_open_join", {
      p_token: token,
      p_name: name,
      p_phone: phone,
      p_status: status,
      p_note: note ?? null,
      p_set_note: note !== undefined,
      p_plus: plus ?? null,
      p_set_plus: plus !== undefined,
    });
    if (error) {
      // the database function raises one of these fixed messages
      if (error.message === "not_found" || error.message === "bad_request") {
        return { error: error.message };
      }
      throw new Error(`guest_rsvp_open_join failed: ${error.message}`);
    }
    // null when an existing guest was reused
    return { token: (data as string | null) ?? null };
  },
};

serve(createHandler(store));
