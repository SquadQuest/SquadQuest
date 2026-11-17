// Request handling for the guest-rsvp function, kept free of Deno and
// Supabase imports so it can be tested against an in-memory store
// (handler.test.ts). index.ts wires it to the service-role client.
//
// Contract: docs/guest-rsvp.md § Contract. Every error is one of a fixed set
// of `{ "error": "<code>" }` bodies, and an unknown token, a closed or full
// open link, an event the guest is not on, and a canceled or draft event all
// answer the same 404, so a caller cannot probe which of those it hit.

export type GuestStatus = "invited" | "yes" | "maybe" | "no";
export type AnswerStatus = "yes" | "maybe" | "no";
/** A cleaned guest note: a string to set, null to clear, undefined to leave as is. */
export type Note = string | null | undefined;
/** Plus-ones: 0-9 to set (0 clears), undefined to leave as is. */
export type Plus = number | undefined;

export interface InstanceRow {
  id: string;
  title: string | null;
  start_time_min: string | null;
  start_time_max: string | null;
  end_time: string | null;
  location_description: string | null;
  notes: string | null;
  banner_photo: string | null;
  status: "draft" | "live" | "canceled";
  created_by: string;
}

export interface GuestRow {
  id: string;
  name: string;
  host: string;
  /** true once the guest signed up and their answers moved to the app */
  claimed: boolean;
}

export interface OpenLinkRow {
  instance: InstanceRow;
  closed_at: string | null;
  max_guests: number;
  guests_created: number;
  /**
   * Plus-ones the link holds: those of guests it created, on its event,
   * answering yes or maybe. The link is full when guests_created plus this
   * reaches max_guests.
   */
  plus_held: number;
}

/** `token` is the guest's token only when this call created the guest. */
export type OpenJoinResult =
  | { token: string | null }
  | { error: "not_found" | "bad_request" };

/** The data the function needs. index.ts implements it with the service role. */
export interface GuestStore {
  guestByToken(token: string): Promise<GuestRow | null>;
  hostFirstName(host: string): Promise<string | null>;
  guestEvents(
    guest: string,
  ): Promise<Array<{ instance: InstanceRow; status: GuestStatus; note: string | null; plus: number }>>;
  /**
   * Sets the answer, and the note and plus-ones too unless undefined (then
   * the stored value is left as it is). Returns false when no row matched,
   * or when the guest was created by the event's open link and the change
   * would take that link over its cap (nothing is written then).
   */
  setAnswer(guest: string, instance: string, status: AnswerStatus, note: Note, plus: Plus): Promise<boolean>;
  /** Whether this host's guest with this phone has been claimed by a member. */
  phoneClaimed(host: string, phone: string): Promise<boolean>;
  openLinkByToken(token: string): Promise<OpenLinkRow | null>;
  /**
   * Atomic find-or-create-guest-by-phone and answer; enforces closed, live
   * and cap (plus-ones included) itself too. `note` or `plus` undefined
   * leaves the stored value as it is.
   */
  openJoin(
    token: string,
    name: string,
    phone: string,
    status: AnswerStatus,
    note: Note,
    plus: Plus,
  ): Promise<OpenJoinResult>;
}

/** One event as the microsite sees it. */
export interface EventPayload {
  id: string;
  title: string | null;
  start: string | null;
  start_max: string | null;
  end: string | null;
  location: string | null;
  notes: string | null;
  banner: string | null;
  event_status: "live" | "canceled";
  rsvp: GuestStatus | null;
  /** the guest's own note for this event; null whenever `rsvp` is */
  note: string | null;
  /**
   * how many extra people the guest is bringing (0-9); 0 whenever `rsvp`
   * is null. Stored whatever the answer: count it only for yes and maybe.
   */
  plus: number;
}

export interface Payload {
  guest: { name: string } | null;
  host: { first_name: string | null };
  events: EventPayload[];
  /**
   * Guest links only: true when the guest has become a SquadQuest member.
   * Their answers then live in the app, so every `rsvp` is null and POST
   * answers 409 `claimed`.
   */
  claimed?: boolean;
}

/** The open-link POST answer. No guest name, and only the one event. */
export interface OpenPayload extends Payload {
  /** true when this request created the guest */
  created: boolean;
  /** the new guest's own token, only when `created`; otherwise null */
  token: string | null;
}

export const LIMITS = {
  /** Longest accepted value for `t` or `o` before it is even looked up. */
  token: 128,
  body: 2048,
  name: 80,
  phoneInput: 32,
  /** guest note, in characters (code points) after cleaning */
  note: 200,
  /** most plus-ones one guest may bring */
  plus: 9,
};

const TOKEN_RE = /^[0-9a-f]{64}$/;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const E164_RE = /^\+[1-9][0-9]{6,14}$/;
const ANSWERS: AnswerStatus[] = ["yes", "maybe", "no"];
// C0 controls except newline, DEL, and C1 controls
// deno-lint-ignore no-control-regex
const CONTROL_RE = /[\u0000-\u0009\u000B-\u001F\u007F-\u009F]/g;

export const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Max-Age": "86400",
};

const ERROR_STATUS = {
  bad_request: 400,
  not_found: 404,
  method_not_allowed: 405,
  claimed: 409,
  too_large: 413,
  server_error: 500,
} as const;

type ErrorCode = keyof typeof ERROR_STATUS;

class Refusal extends Error {
  constructor(readonly code: ErrorCode) {
    super(code);
  }
}

function respond(status: number, body: unknown): Response {
  return new Response(body === null ? null : JSON.stringify(body), {
    status,
    headers: {
      ...CORS_HEADERS,
      "Content-Type": "application/json",
      // personal data behind a bearer link: never cache it anywhere
      "Cache-Control": "no-store",
    },
  });
}

function refuse(code: ErrorCode): never {
  throw new Refusal(code);
}

function toEvent(
  instance: InstanceRow,
  rsvp: GuestStatus | null,
  note: string | null,
  plus: number,
): EventPayload {
  return {
    id: instance.id,
    title: instance.title,
    start: instance.start_time_min,
    start_max: instance.start_time_max,
    end: instance.end_time,
    location: instance.location_description,
    notes: instance.notes,
    banner: instance.banner_photo,
    event_status: instance.status === "canceled" ? "canceled" : "live",
    rsvp,
    note,
    plus,
  };
}

function byStart(a: EventPayload, b: EventPayload): number {
  return (a.start ?? "").localeCompare(b.start ?? "");
}

/** A token is either well-formed or treated exactly like an unknown one. */
function token(value: unknown): string {
  if (typeof value !== "string" || value.length > LIMITS.token || !TOKEN_RE.test(value)) {
    refuse("not_found");
  }
  return value;
}

/**
 * Accept E.164 as is, or a US number typed as 10 digits (or 11 starting
 * with 1) with any spaces, dots, dashes or parentheses. Anything else is
 * refused rather than guessed at.
 */
export function normalizePhone(value: unknown): string | null {
  if (typeof value !== "string" || value.length > LIMITS.phoneInput) return null;
  const trimmed = value.trim();
  const digits = trimmed.replace(/[\s().-]/g, "");
  if (trimmed.startsWith("+")) return E164_RE.test(digits) ? digits : null;
  if (/^[2-9][0-9]{2}[2-9][0-9]{6}$/.test(digits)) return `+1${digits}`;
  if (/^1[2-9][0-9]{2}[2-9][0-9]{6}$/.test(digits)) return `+${digits}`;
  return null;
}

/**
 * The optional `note` of a POST body. Omitted: undefined (leave the stored
 * note alone). null, or a string that is empty once control characters
 * (all but newline) are removed and it is trimmed: null (clear). Otherwise
 * the cleaned string, at most LIMITS.note characters. Anything else is
 * refused. Plain text: clients render it as text only.
 */
export function parseNote(body: Record<string, unknown>): Note {
  if (!("note" in body)) return undefined;
  const value = body.note;
  if (value === null) return null;
  if (typeof value !== "string") refuse("bad_request");
  // lone surrogates cannot be stored as UTF-8
  const cleaned = value.toWellFormed().replace(CONTROL_RE, "").trim();
  if (cleaned === "") return null;
  if ([...cleaned].length > LIMITS.note) refuse("bad_request");
  return cleaned;
}

/**
 * The optional `plus` of a POST body: how many extra people come with the
 * guest. Omitted: undefined (leave the stored value alone). null: 0. An
 * integer 0 to LIMITS.plus as a JSON number. Anything else (a fraction, a
 * numeric string, a negative, over the limit) is refused.
 */
export function parsePlus(body: Record<string, unknown>): Plus {
  if (!("plus" in body)) return undefined;
  const value = body.plus;
  if (value === null) return 0;
  if (typeof value !== "number" || !Number.isInteger(value) || value < 0 || value > LIMITS.plus) {
    refuse("bad_request");
  }
  return value;
}

function answer(value: unknown): AnswerStatus {
  if (typeof value !== "string" || !ANSWERS.includes(value as AnswerStatus)) {
    refuse("bad_request");
  }
  return value as AnswerStatus;
}

async function guestPayload(store: GuestStore, guest: GuestRow): Promise<Payload> {
  const rows = await store.guestEvents(guest.id);
  const events = rows
    // only the host's own events, and never a draft
    .filter((r) => r.instance.created_by === guest.host && r.instance.status !== "draft")
    // a claimed guest's answers are member RSVPs now; never show a stale one
    .map((r) =>
      guest.claimed ? toEvent(r.instance, null, null, 0) : toEvent(r.instance, r.status, r.note, r.plus)
    )
    .sort(byStart);
  return {
    guest: { name: guest.name },
    host: { first_name: await store.hostFirstName(guest.host) },
    events,
    claimed: guest.claimed,
  };
}

async function openLink(store: GuestStore, value: unknown): Promise<OpenLinkRow> {
  const link = await store.openLinkByToken(token(value));
  if (
    !link ||
    link.closed_at !== null ||
    link.instance.status !== "live" ||
    // full: guests created plus the plus-ones they bring
    link.guests_created + link.plus_held >= link.max_guests
  ) {
    refuse("not_found");
  }
  return link;
}

async function handleGet(store: GuestStore, url: URL): Promise<Response> {
  const t = url.searchParams.get("t");
  const o = url.searchParams.get("o");
  if ((t === null) === (o === null)) refuse("bad_request");

  if (t !== null) {
    const guest = await store.guestByToken(token(t));
    if (!guest) refuse("not_found");
    return respond(200, await guestPayload(store, guest));
  }

  const link = await openLink(store, o);
  const payload: Payload = {
    guest: null,
    host: { first_name: await store.hostFirstName(link.instance.created_by) },
    events: [toEvent(link.instance, null, null, 0)],
  };
  return respond(200, payload);
}

async function readBody(request: Request): Promise<Record<string, unknown>> {
  const declared = Number(request.headers.get("content-length") ?? "0");
  if (declared > LIMITS.body) refuse("too_large");
  const text = await request.text();
  if (text.length > LIMITS.body) refuse("too_large");
  let body: unknown;
  try {
    body = JSON.parse(text);
  } catch {
    refuse("bad_request");
  }
  if (typeof body !== "object" || body === null || Array.isArray(body)) refuse("bad_request");
  return body as Record<string, unknown>;
}

async function handlePost(store: GuestStore, request: Request): Promise<Response> {
  const body = await readBody(request);
  const hasT = "t" in body;
  const hasO = "o" in body;
  if (hasT === hasO) refuse("bad_request");
  const status = answer(body.status);
  const note = parseNote(body);
  const plus = parsePlus(body);

  if (hasT) {
    const guest = await store.guestByToken(token(body.t));
    if (!guest) refuse("not_found");
    // the member answers in the app; a bearer link must not change a real RSVP
    if (guest.claimed) refuse("claimed");
    const instance = body.instance;
    if (typeof instance !== "string" || !UUID_RE.test(instance)) refuse("not_found");

    const current = (await store.guestEvents(guest.id)).find(
      (r) =>
        r.instance.id === instance &&
        r.instance.created_by === guest.host &&
        r.instance.status === "live",
    );
    if (!current) refuse("not_found");
    // a status-only answer (no `note` or `plus` key) never touches the
    // stored note or plus-ones
    const noteChanged = note !== undefined && note !== current.note;
    const plusChanged = plus !== undefined && plus !== current.plus;
    if (
      (current.status !== status || noteChanged || plusChanged) &&
      !(await store.setAnswer(
        guest.id,
        instance,
        status,
        noteChanged ? note : undefined,
        plusChanged ? plus : undefined,
      ))
    ) {
      refuse("not_found");
    }
    // read back what was stored rather than echoing the request
    return respond(200, await guestPayload(store, guest));
  }

  // open link: validate everything before the store is touched
  const o = token(body.o);
  const rawName = body.name;
  if (typeof rawName !== "string") refuse("bad_request");
  const name = rawName.trim();
  if (name.length < 1 || name.length > LIMITS.name) refuse("bad_request");
  const phone = normalizePhone(body.phone);
  if (phone === null) refuse("bad_request");

  const link = await openLink(store, o);
  // A phone whose guest became a member answers in the app. Refused rather
  // than recorded: the caller proved only knowledge of the number, which may
  // not be theirs, and a guest-side answer would diverge from the member's.
  if (await store.phoneClaimed(link.instance.created_by, phone)) refuse("claimed");
  const joined = await store.openJoin(o, name, phone, status, note, plus);
  if ("error" in joined) refuse(joined.error);

  // Only this event and the answer just set. Never the guest's stored name,
  // stored note or plus-ones or other events, and a token only for a guest
  // created right now: the caller proved nothing but knowledge of a phone
  // number. So `note` and `plus` are what this request set, or null and 0
  // when it sent none.
  const payload: OpenPayload = {
    created: joined.token !== null,
    token: joined.token,
    guest: null,
    host: { first_name: await store.hostFirstName(link.instance.created_by) },
    events: [toEvent(link.instance, status, note ?? null, plus ?? 0)],
  };
  return respond(200, payload);
}

export function createHandler(store: GuestStore, log: (e: unknown) => void = console.error) {
  return async (request: Request): Promise<Response> => {
    try {
      if (request.method === "OPTIONS") return respond(204, null);
      // the gateway may forward the full /guest-rsvp path; only the query matters
      const url = new URL(request.url);
      if (request.method === "GET") return await handleGet(store, url);
      if (request.method === "POST") return await handlePost(store, request);
      refuse("method_not_allowed");
    } catch (error) {
      if (error instanceof Refusal) {
        return respond(ERROR_STATUS[error.code], { error: error.code });
      }
      // never echo internals to an unauthenticated caller
      log(error);
      return respond(500, { error: "server_error" });
    }
  };
}
