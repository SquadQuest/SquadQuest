// Tests for the guest-rsvp handler against an in-memory store. No network,
// no database: run with
//
//   deno test supabase/functions/guest-rsvp/handler.test.ts
//
// Invented people only.
import {
  AnswerStatus,
  createHandler,
  GuestStatus,
  GuestStore,
  InstanceRow,
  OpenLinkRow,
} from "./handler.ts";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(`assertion failed: ${message}`);
}

function assertEquals(actual: unknown, expected: unknown, message = "") {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e) throw new Error(`assertion failed: ${message}\n  actual:   ${a}\n  expected: ${e}`);
}

const HOST = "00000000-0000-4000-8000-0000000000a1";
const OTHER_HOST = "00000000-0000-4000-8000-0000000000a2";
const GUEST = "00000000-0000-4000-8000-0000000000b1";
const TOKEN = "a".repeat(64);
const OPEN = "c".repeat(64);
const UNKNOWN = "f".repeat(64);
const E_LIVE = "00000000-0000-4000-8000-0000000000e1";
const E_LATER = "00000000-0000-4000-8000-0000000000e2";
const E_CANCELED = "00000000-0000-4000-8000-0000000000e3";
const E_DRAFT = "00000000-0000-4000-8000-0000000000e4";
const E_FOREIGN = "00000000-0000-4000-8000-0000000000e5";
const E_NOT_ON = "00000000-0000-4000-8000-0000000000e6";

function instance(id: string, start: string, extra: Partial<InstanceRow> = {}): InstanceRow {
  return {
    id,
    title: `Event ${id.slice(-2)}`,
    start_time_min: start,
    start_time_max: start,
    end_time: null,
    location_description: "Somewhere",
    notes: null,
    banner_photo: null,
    status: "live",
    created_by: HOST,
    ...extra,
  };
}

interface World {
  guests: Array<{ id: string; name: string; host: string; token: string; phone: string | null; claimed?: boolean }>;
  rows: Array<{ guest: string; instance: InstanceRow; status: GuestStatus }>;
  links: Array<OpenLinkRow & { token: string }>;
  writes: number;
}

function world(): World {
  const later = instance(E_LATER, "2026-12-02T00:00:00+00:00", { banner_photo: "https://example.com/b.png" });
  const live = instance(E_LIVE, "2026-12-01T00:00:00+00:00", { notes: "Bring a snack" });
  return {
    guests: [{ id: GUEST, name: "Sam Example", host: HOST, token: TOKEN, phone: "+15555550100" }],
    rows: [
      { guest: GUEST, instance: later, status: "invited" },
      { guest: GUEST, instance: live, status: "yes" },
      { guest: GUEST, instance: instance(E_CANCELED, "2026-12-03T00:00:00+00:00", { status: "canceled" }), status: "maybe" },
      { guest: GUEST, instance: instance(E_DRAFT, "2026-12-04T00:00:00+00:00", { status: "draft" }), status: "invited" },
      { guest: GUEST, instance: instance(E_FOREIGN, "2026-12-05T00:00:00+00:00", { created_by: OTHER_HOST }), status: "invited" },
    ],
    links: [{ token: OPEN, instance: live, closed_at: null, max_guests: 300, guests_created: 0 }],
    writes: 0,
  };
}

function storeFor(w: World): GuestStore {
  return {
    guestByToken: async (t) => {
      const g = w.guests.find((g) => g.token === t);
      return g ? { id: g.id, name: g.name, host: g.host, claimed: g.claimed === true } : null;
    },
    hostFirstName: async (h) => (h === HOST ? "Host" : null),
    guestEvents: async (g) => w.rows.filter((r) => r.guest === g).map((r) => ({ instance: r.instance, status: r.status })),
    setStatus: async (g, i, s: AnswerStatus) => {
      w.writes++;
      const row = w.rows.find((r) => r.guest === g && r.instance.id === i);
      if (!row) return false;
      row.status = s;
      return true;
    },
    phoneClaimed: async (h, p) => w.guests.some((g) => g.host === h && g.phone === p && g.claimed === true),
    openLinkByToken: async (t) => w.links.find((l) => l.token === t) ?? null,
    openJoin: async (t, name, phone, status) => {
      w.writes++;
      const link = w.links.find((l) => l.token === t);
      if (!link || link.closed_at || link.instance.status !== "live" || link.guests_created >= link.max_guests) {
        return { error: "not_found" };
      }
      const host = link.instance.created_by;
      let guest = w.guests.find((g) => g.host === host && g.phone === phone);
      let created = false;
      if (!guest) {
        const id = `00000000-0000-4000-8000-${String(w.guests.length).padStart(12, "0")}`;
        guest = { id, name, host, token: String(w.guests.length).padStart(64, "d"), phone };
        w.guests.push(guest);
        link.guests_created++;
        created = true;
      }
      const row = w.rows.find((r) => r.guest === guest!.id && r.instance.id === link.instance.id);
      if (row) row.status = status;
      else w.rows.push({ guest: guest.id, instance: link.instance, status });
      return { token: created ? guest.token : null };
    },
  };
}

const BASE = "http://functions:9000/guest-rsvp";

function get(query: string) {
  return new Request(`${BASE}?${query}`, { method: "GET" });
}

function post(body: unknown) {
  return new Request(BASE, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

async function call(w: World, request: Request) {
  const response = await createHandler(storeFor(w), () => {})(request);
  const text = await response.text();
  return { status: response.status, headers: response.headers, body: text ? JSON.parse(text) : null };
}

Deno.test("GET ?t returns the guest, host and only their live/canceled events from that host, sorted", async () => {
  const r = await call(world(), get(`t=${TOKEN}`));
  assertEquals(r.status, 200);
  assertEquals(r.body.guest, { name: "Sam Example" });
  assertEquals(r.body.host, { first_name: "Host" });
  assertEquals(r.body.events.map((e: { id: string }) => e.id), [E_LIVE, E_LATER, E_CANCELED]);
  assertEquals(r.body.events[0], {
    id: E_LIVE,
    title: "Event e1",
    start: "2026-12-01T00:00:00+00:00",
    start_max: "2026-12-01T00:00:00+00:00",
    end: null,
    location: "Somewhere",
    notes: "Bring a snack",
    banner: null,
    event_status: "live",
    rsvp: "yes",
  }, "event field set");
  assertEquals(r.body.events[2].event_status, "canceled");
});

Deno.test("every response carries open CORS and no-store", async () => {
  for (const req of [get(`t=${TOKEN}`), get(`t=${UNKNOWN}`), new Request(BASE, { method: "OPTIONS" })]) {
    const r = await call(world(), req);
    assertEquals(r.headers.get("access-control-allow-origin"), "*");
    assertEquals(r.headers.get("access-control-allow-methods"), "GET, POST, OPTIONS");
    assertEquals(r.headers.get("cache-control"), "no-store");
  }
  assertEquals((await call(world(), new Request(BASE, { method: "OPTIONS" }))).status, 204);
});

Deno.test("POST ?t sets the answer and returns the stored state", async () => {
  const w = world();
  const r = await call(w, post({ t: TOKEN, instance: E_LATER, status: "maybe" }));
  assertEquals(r.status, 200);
  assertEquals(r.body.events.find((e: { id: string }) => e.id === E_LATER).rsvp, "maybe");
  assertEquals(w.writes, 1);
});

Deno.test("POST with the current answer writes nothing and still returns 200", async () => {
  const w = world();
  const r = await call(w, post({ t: TOKEN, instance: E_LIVE, status: "yes" }));
  assertEquals(r.status, 200);
  assertEquals(w.writes, 0);
});

Deno.test("unknown token, event not on, canceled, draft and foreign events all give the same 404", async () => {
  const cases = [
    get(`t=${UNKNOWN}`),
    get("t=short"),
    get(`t=${"x".repeat(500)}`),
    post({ t: UNKNOWN, instance: E_LIVE, status: "yes" }),
    post({ t: TOKEN, instance: E_NOT_ON, status: "yes" }),
    post({ t: TOKEN, instance: E_CANCELED, status: "yes" }),
    post({ t: TOKEN, instance: E_DRAFT, status: "yes" }),
    post({ t: TOKEN, instance: E_FOREIGN, status: "yes" }),
    post({ t: TOKEN, instance: "not-a-uuid", status: "yes" }),
  ];
  const w = world();
  for (const req of cases) {
    const r = await call(w, req);
    assertEquals([r.status, r.body], [404, { error: "not_found" }], `${req.method} ${req.url}`);
  }
  assertEquals(w.writes, 0, "nothing written");
});

Deno.test("malformed input is a constant-shape 400, 405 or 413", async () => {
  const w = world();
  const expect = async (req: Request, status: number, error: string) => {
    const r = await call(w, req);
    assertEquals([r.status, r.body], [status, { error }], `${req.method} ${req.url}`);
  };
  await expect(get(""), 400, "bad_request");
  await expect(get(`t=${TOKEN}&o=${OPEN}`), 400, "bad_request");
  await expect(post("not json"), 400, "bad_request");
  await expect(post([1]), 400, "bad_request");
  await expect(post({ t: TOKEN, instance: E_LIVE, status: "omw" }), 400, "bad_request");
  await expect(post({ t: TOKEN, instance: E_LIVE, status: "invited" }), 400, "bad_request");
  await expect(post({ t: TOKEN, o: OPEN, status: "yes" }), 400, "bad_request");
  await expect(post({ t: TOKEN, instance: E_LIVE, status: "yes", pad: "x".repeat(3000) }), 413, "too_large");
  await expect(new Request(BASE, { method: "DELETE" }), 405, "method_not_allowed");
  assertEquals(w.writes, 0);
});

Deno.test("a store failure is a bare 500 that leaks nothing", async () => {
  const store = storeFor(world());
  store.guestByToken = () => Promise.reject(new Error("secret internals"));
  const response = await createHandler(store, () => {})(get(`t=${TOKEN}`));
  assertEquals(response.status, 500);
  assertEquals(await response.json(), { error: "server_error" });
});

// ── open links ──────────────────────────────────────────────────────

Deno.test("GET ?o returns the one event with no guest and no answer", async () => {
  const r = await call(world(), get(`o=${OPEN}`));
  assertEquals(r.status, 200);
  assertEquals(r.body.guest, null);
  assertEquals(r.body.host, { first_name: "Host" });
  assertEquals(r.body.events.length, 1);
  assertEquals(r.body.events[0].id, E_LIVE);
  assertEquals(r.body.events[0].rsvp, null);
});

Deno.test("POST ?o creates a guest by phone, records the answer and returns their own token", async () => {
  const w = world();
  const r = await call(w, post({ o: OPEN, name: "  Pat ", phone: "(215) 555-0199", status: "maybe" }));
  assertEquals(r.status, 200);
  assertEquals(r.body.created, true);
  assert(typeof r.body.token === "string" && r.body.token.length === 64, "token returned");
  assertEquals(r.body.guest, null, "no guest name in the open flow");
  assertEquals(r.body.events.map((e: { id: string; rsvp: string }) => [e.id, e.rsvp]), [[E_LIVE, "maybe"]]);
  const stored = w.guests.find((g) => g.token === r.body.token)!;
  assertEquals([stored.name, stored.phone], ["Pat", "+12155550199"], "name trimmed, phone normalized");

  // the token works in the normal flow
  const again = await call(w, post({ t: r.body.token, instance: E_LIVE, status: "no" }));
  assertEquals(again.body.events[0].rsvp, "no");
});

Deno.test("POST ?o with a phone already on the list reuses the guest and returns no token, name or other events", async () => {
  const w = world();
  // Sam was added by the host and is on five events
  const r = await call(w, post({ o: OPEN, name: "Somebody", phone: "+1 555 555 0100", status: "no" }));
  assertEquals(r.status, 200);
  assertEquals(r.body.created, false);
  assertEquals(r.body.token, null, "no token for an existing guest");
  assertEquals(r.body.guest, null, "stored name never returned");
  assertEquals(r.body.events.length, 1, "only this event");
  assertEquals([r.body.events[0].id, r.body.events[0].rsvp], [E_LIVE, "no"]);
  assert(!JSON.stringify(r.body).includes("Sam Example"), "stored name absent");
  assert(!JSON.stringify(r.body).includes(TOKEN), "stored token absent");
  assertEquals(w.guests.length, 1, "no duplicate guest");
  assertEquals(w.guests[0].name, "Sam Example", "stored name kept");
  assertEquals(w.rows.find((x) => x.instance.id === E_LIVE)!.status, "no", "answer updated");
});

Deno.test("phone normalization: E.164 and US 10/11-digit accepted, everything else refused", async () => {
  const { normalizePhone } = await import("./handler.ts");
  assertEquals(normalizePhone("+15555550100"), "+15555550100");
  assertEquals(normalizePhone("+44 20 7946 0958"), "+442079460958");
  assertEquals(normalizePhone("215-555-0100"), "+12155550100");
  assertEquals(normalizePhone("(215) 555.0100"), "+12155550100");
  assertEquals(normalizePhone("1 215 555 0100"), "+12155550100");
  for (const bad of ["", "555-0100", "0215550100", "2151550100", "12345678", "22155550100", "+0123", "215555010x", "+1".padEnd(40, "5"), 2155550100, null]) {
    assertEquals(normalizePhone(bad), null, String(bad));
  }
});

Deno.test("POST ?o requires a valid phone and a name, checked before touching the store", async () => {
  const w = world();
  for (const body of [
    { o: OPEN, name: "Lee", status: "yes" },
    { o: OPEN, name: "Lee", phone: "", status: "yes" },
    { o: OPEN, name: "Lee", phone: "555-0100", status: "yes" },
    { o: OPEN, name: "Lee", phone: 2155550100, status: "yes" },
    { o: OPEN, phone: "2155550100", status: "yes" },
    { o: OPEN, name: "   ", phone: "2155550100", status: "yes" },
    { o: OPEN, name: "x".repeat(81), phone: "2155550100", status: "yes" },
    { o: OPEN, name: "Lee", phone: "2155550100", status: "invited" },
  ]) {
    const r = await call(w, post(body));
    assertEquals([r.status, r.body], [400, { error: "bad_request" }], JSON.stringify(body));
  }
  assertEquals(w.writes, 0);
});

Deno.test("closed, full, canceled and unknown open links all give the same 404", async () => {
  const setups: Array<(w: World) => void> = [
    (w) => (w.links[0].closed_at = "2026-11-01T00:00:00Z"),
    (w) => (w.links[0].guests_created = 300),
    (w) => (w.links[0].instance = { ...w.links[0].instance, status: "canceled" }),
    (w) => (w.links[0].token = UNKNOWN),
  ];
  for (const setup of setups) {
    const w = world();
    setup(w);
    for (const req of [get(`o=${OPEN}`), post({ o: OPEN, name: "Lee", phone: "2155550198", status: "yes" })]) {
      const r = await call(w, req);
      assertEquals([r.status, r.body], [404, { error: "not_found" }], `${req.method} ${setup}`);
    }
    assertEquals(w.writes, 0, "nothing written");
  }
});

Deno.test("the cap is enforced: the 301st new guest is refused", async () => {
  const w = world();
  w.links[0].guests_created = 299;
  assertEquals((await call(w, post({ o: OPEN, name: "Last", phone: "2155550197", status: "yes" }))).status, 200);
  const r = await call(w, post({ o: OPEN, name: "Late", phone: "2155550196", status: "yes" }));
  assertEquals([r.status, r.body], [404, { error: "not_found" }]);
});

Deno.test("a claimed guest's link still shows their events, with no answers, and flags claimed", async () => {
  const w = world();
  const before = await call(w, get(`t=${TOKEN}`));
  assertEquals(before.body.claimed, false);
  w.guests[0].claimed = true;
  const r = await call(w, get(`t=${TOKEN}`));
  assertEquals(r.status, 200);
  assertEquals(r.body.claimed, true);
  assertEquals(r.body.guest, { name: "Sam Example" });
  assertEquals(r.body.events.map((e: { id: string }) => e.id), [E_LIVE, E_LATER, E_CANCELED]);
  assertEquals(r.body.events.map((e: { rsvp: string | null }) => e.rsvp), [null, null, null], "no stale answers");
});

Deno.test("a claimed guest's link refuses answers with 409 claimed and writes nothing", async () => {
  const w = world();
  w.guests[0].claimed = true;
  const r = await call(w, post({ t: TOKEN, instance: E_LIVE, status: "no" }));
  assertEquals(r.status, 409);
  assertEquals(r.body, { error: "claimed" });
  assertEquals(w.writes, 0);
  assertEquals(w.rows.find((x) => x.instance.id === E_LIVE)!.status, "yes", "answer unchanged");
});

Deno.test("an open-link answer with a claimed guest's phone is refused with 409 and writes nothing", async () => {
  const w = world();
  w.guests[0].claimed = true;
  const r = await call(w, post({ o: OPEN, name: "Somebody", phone: "+15555550100", status: "no" }));
  assertEquals(r.status, 409);
  assertEquals(r.body, { error: "claimed" });
  assertEquals(w.writes, 0);
  // another phone on the same link still works
  const ok = await call(w, post({ o: OPEN, name: "Pat", phone: "+15555550199", status: "yes" }));
  assertEquals(ok.status, 200);
});
