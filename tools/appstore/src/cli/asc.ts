/**
 * App Store Connect API client.
 *
 * Auth is an ES256 JWT signed with a team API key. The key is read from disk
 * rather than an env var because Apple's own tooling (xcodebuild, fastlane)
 * already looks in ~/.appstoreconnect/private_keys, so keeping it there means
 * one copy serves every tool and nothing sensitive lands in the repo.
 */
import { createHmac, createSign, KeyObject, createPrivateKey } from "node:crypto";
import { readFileSync, readdirSync, existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { AxiError } from "axi-sdk-js";

export const KEY_DIR = join(homedir(), ".appstoreconnect", "private_keys");

/** SquadQuest's identifiers. Hardcoded because this CLI ships with the app. */
export const APP_BUNDLE_ID = "app.squadquest";
export const EXTENSION_BUNDLE_ID = "app.squadquest.ImageNotification";
export const TEAM_ID = "64TVJXTLTT";

export interface Credentials {
  issuerId: string;
  keyId: string;
  privateKey: string;
}

/**
 * Resolve credentials. The issuer id is stable per team, so it can live in an
 * env var or a sidecar file next to the key; the key id is inferred from the
 * AuthKey_<id>.p8 filename so there's only one thing to keep in sync.
 */
export function loadCredentials(): Credentials {
  const issuerId = process.env.APPSTORE_ISSUER_ID ?? readIssuerFile();
  if (!issuerId) {
    throw new AxiError(
      "No App Store Connect issuer id found",
      "missing-issuer-id",
      [
        `Set APPSTORE_ISSUER_ID, or write it to ${collapse(join(KEY_DIR, "issuer_id"))}`,
        "Find it at App Store Connect > Users and Access > Integrations > App Store Connect API",
      ],
    );
  }

  const explicit = process.env.APPSTORE_API_KEY_ID;
  const keyPath = explicit
    ? join(KEY_DIR, `AuthKey_${explicit}.p8`)
    : findSingleKey();

  if (!existsSync(keyPath)) {
    throw new AxiError(`No API key at ${collapse(keyPath)}`, "missing-api-key", [
      `Download a team key and save it as ${collapse(KEY_DIR)}/AuthKey_<id>.p8`,
      "chmod 600 the file — it is an account credential",
    ]);
  }

  const keyId = keyPath.replace(/.*AuthKey_/, "").replace(/\.p8$/, "");
  return { issuerId, keyId, privateKey: readFileSync(keyPath, "utf8") };
}

function readIssuerFile(): string | undefined {
  const path = join(KEY_DIR, "issuer_id");
  return existsSync(path) ? readFileSync(path, "utf8").trim() : undefined;
}

function findSingleKey(): string {
  let entries: string[] = [];
  try {
    entries = readdirSync(KEY_DIR).filter((f) => /^AuthKey_.+\.p8$/.test(f));
  } catch {
    entries = [];
  }

  if (entries.length === 0) {
    return join(KEY_DIR, "AuthKey_<id>.p8");
  }
  if (entries.length > 1) {
    throw new AxiError(
      `Multiple API keys in ${collapse(KEY_DIR)}`,
      "ambiguous-api-key",
      [
        `Set APPSTORE_API_KEY_ID to pick one: ${entries
          .map((f) => f.replace(/^AuthKey_|\.p8$/g, ""))
          .join(", ")}`,
      ],
    );
  }
  return join(KEY_DIR, entries[0]!);
}

function collapse(p: string): string {
  const home = homedir();
  return home && p.startsWith(`${home}/`) ? `~${p.slice(home.length)}` : p;
}

function base64url(input: Buffer | string): string {
  return Buffer.from(input)
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

/**
 * Apple caps token lifetime at 20 minutes; 15 leaves headroom for a slow
 * upload without risking rejection for an over-long expiry.
 */
function mintToken({ issuerId, keyId, privateKey }: Credentials): string {
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: "ES256", kid: keyId, typ: "JWT" }));
  const payload = base64url(
    JSON.stringify({ iss: issuerId, iat: now, exp: now + 900, aud: "appstoreconnect-v1" }),
  );

  let key: KeyObject;
  try {
    key = createPrivateKey(privateKey);
  } catch {
    throw new AxiError("API key is not a readable private key", "bad-api-key", [
      "Re-download AuthKey_<id>.p8 from App Store Connect (it can only be downloaded once)",
    ]);
  }

  const signer = createSign("SHA256");
  signer.update(`${header}.${payload}`);
  const der = signer.sign({ key, dsaEncoding: "ieee-p1363" });
  return `${header}.${payload}.${base64url(der)}`;
}

let cachedToken: { token: string; expires: number } | undefined;

function token(): string {
  if (cachedToken && cachedToken.expires > Date.now() + 60_000) return cachedToken.token;
  const t = mintToken(loadCredentials());
  cachedToken = { token: t, expires: Date.now() + 900_000 };
  return t;
}

const BASE = "https://api.appstoreconnect.apple.com";

export interface AscResource {
  id: string;
  type: string;
  attributes?: Record<string, any>;
  relationships?: Record<string, any>;
}

export interface AscResponse {
  data?: AscResource | AscResource[];
  included?: AscResource[];
  links?: Record<string, string>;
  errors?: Array<{ title?: string; detail?: string; code?: string }>;
}

/**
 * One request. Apple returns errors as a JSON `errors` array with a useful
 * `detail`, so surface that rather than a bare status code — a 409 saying
 * "the build is still processing" is far more actionable than "409".
 */
export async function request(
  method: string,
  path: string,
  body?: unknown,
): Promise<AscResponse> {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${token()}`,
      ...(body ? { "Content-Type": "application/json" } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });

  const text = await res.text();
  const json: AscResponse = text ? JSON.parse(text) : {};

  if (!res.ok) {
    const detail = json.errors?.[0]?.detail ?? json.errors?.[0]?.title ?? `HTTP ${res.status}`;
    const code = json.errors?.[0]?.code ?? `http-${res.status}`;
    throw new AxiError(detail, String(code).toLowerCase(), suggestFor(res.status));
  }

  return json;
}

function suggestFor(status: number): string[] {
  if (status === 401) {
    return [
      "The JWT was rejected — check APPSTORE_ISSUER_ID matches the key's team",
      "Keys are per-team; an individual key won't work here",
    ];
  }
  if (status === 403) {
    return [
      "The key's role is too narrow for this operation",
      "Creating profiles or certificates needs an Admin key; App Manager can only read them",
    ];
  }
  return [];
}

/** Follow pagination so callers never silently see a truncated list. */
export async function requestAll(path: string): Promise<AscResponse> {
  const first = await request("GET", path);
  const data = Array.isArray(first.data) ? [...first.data] : [];
  const included = [...(first.included ?? [])];

  let next = first.links?.next;
  while (next) {
    const res = await request("GET", next.replace(BASE, ""));
    if (Array.isArray(res.data)) data.push(...res.data);
    if (res.included) included.push(...res.included);
    next = res.links?.next;
  }

  return { data, included };
}

/** The app record, looked up by bundle id so nothing hardcodes an opaque id. */
export async function getApp(): Promise<AscResource> {
  const res = await request(
    "GET",
    `/v1/apps?filter%5BbundleId%5D=${encodeURIComponent(APP_BUNDLE_ID)}&limit=10`,
  );
  const apps = (Array.isArray(res.data) ? res.data : []).filter(
    (a) => a.attributes?.bundleId === APP_BUNDLE_ID,
  );
  const app = apps[0];
  if (!app) {
    throw new AxiError(`No app found for ${APP_BUNDLE_ID}`, "app-not-found", [
      "Check the API key's team owns this app",
    ]);
  }
  return app;
}
