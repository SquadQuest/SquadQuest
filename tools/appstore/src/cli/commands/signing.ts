/**
 * Signing assets: profiles, certificates, devices.
 *
 * These exist because CI deliberately holds a narrow App Manager key that can
 * read signing assets but not create them. When a profile expires or a device
 * is added, the build breaks and nothing in CI can fix it — so the repair path
 * lives here, driven by an Admin key held locally.
 */
import { AxiError } from "axi-sdk-js";
import {
  APP_BUNDLE_ID,
  EXTENSION_BUNDLE_ID,
  request,
  requestAll,
  type AscResource,
} from "../asc.js";
import { cliInvocation } from "../invocation.js";

const APP_STORE_PROFILE = "IOS_APP_STORE";

/** Profile names the release workflow's ExportOptions.plist pins, by bundle id. */
export const PROFILE_NAMES: Record<string, string> = {
  [APP_BUNDLE_ID]: "SquadQuest App Store",
  [EXTENSION_BUNDLE_ID]: "SquadQuest ImageNotification App Store",
};

export const RELEASE_PROFILE_NAMES = Object.values(PROFILE_NAMES);

function daysUntil(iso: string | undefined): number | undefined {
  if (!iso) return undefined;
  return Math.round((new Date(iso).getTime() - Date.now()) / 86_400_000);
}

async function squadquestProfiles() {
  const res = await requestAll("/v1/profiles?limit=200&include=bundleId");
  const bundleIds = new Map(
    (res.included ?? [])
      .filter((i) => i.type === "bundleIds")
      .map((b) => [b.id, b.attributes?.identifier as string]),
  );

  return (Array.isArray(res.data) ? res.data : [])
    .map((p) => ({
      resource: p,
      bundleId: bundleIds.get(p.relationships?.bundleId?.data?.id ?? "") ?? "",
    }))
    .filter(({ bundleId }) => bundleId in PROFILE_NAMES);
}

export async function profilesList() {
  const found = await squadquestProfiles();

  const rows = found.map(({ resource, bundleId }) => {
    const days = daysUntil(resource.attributes?.expirationDate);
    return {
      name: resource.attributes?.name,
      bundleId,
      type: resource.attributes?.profileType,
      state: resource.attributes?.profileState,
      expires: (resource.attributes?.expirationDate ?? "").slice(0, 10),
      daysLeft: days,
    };
  });

  // Warn only about the App Store profiles a release build pins. Stale
  // development profiles are listed for context but can't break a release,
  // and `profiles regenerate` wouldn't touch them anyway.
  const problems = rows
    .filter((r) => r.type === APP_STORE_PROFILE)
    .filter((r) => r.state !== "ACTIVE" || (r.daysLeft ?? 999) < 30)
    .map((r) =>
      r.state !== "ACTIVE"
        ? `${r.name} is ${r.state}`
        : `${r.name} expires in ${r.daysLeft} days`,
    );

  const missing = Object.entries(PROFILE_NAMES)
    .filter(([bundleId]) => !rows.some((r) => r.bundleId === bundleId))
    .map(([bundleId, name]) => `no ${APP_STORE_PROFILE} profile for ${bundleId} (expected "${name}")`);

  return {
    profiles: rows,
    ...(problems.length || missing.length
      ? {
          attention: [...problems, ...missing],
          help: [`Run \`${cliInvocation()} profiles regenerate\` to recreate them`],
        }
      : {}),
  };
}

async function distributionCertificate(): Promise<AscResource> {
  const res = await requestAll("/v1/certificates?limit=200");
  const certs = (Array.isArray(res.data) ? res.data : []).filter(
    (c) => c.attributes?.certificateType === "DISTRIBUTION",
  );

  // Prefer the longest-lived valid one; a nearly-expired cert would mint a
  // profile that dies with it.
  const sorted = certs
    .filter((c) => (daysUntil(c.attributes?.expirationDate) ?? -1) > 0)
    .sort(
      (a, b) =>
        (daysUntil(b.attributes?.expirationDate) ?? 0) -
        (daysUntil(a.attributes?.expirationDate) ?? 0),
    );

  const cert = sorted[0];
  if (!cert) {
    throw new AxiError("No valid distribution certificate", "no-distribution-cert", [
      "Create one in the Developer portal, then update APPLE_CERTIFICATE_BASE64 in GitHub secrets",
    ]);
  }
  return cert;
}

/**
 * Recreating a profile means deleting and re-adding it: Apple has no "renew".
 * Keeping the same name is what makes this safe — ExportOptions.plist pins
 * profiles by name, so the workflow needs no change afterwards.
 */
export async function profilesRegenerate(args: string[]) {
  const only = args.includes("--bundle-id") ? args[args.indexOf("--bundle-id") + 1] : undefined;
  if (only && !(only in PROFILE_NAMES)) {
    throw new AxiError(`Unknown bundle id ${only}`, "unknown-bundle-id", [
      `Known: ${Object.keys(PROFILE_NAMES).join(", ")}`,
    ]);
  }

  const targets = only ? [only] : Object.keys(PROFILE_NAMES);
  const cert = await distributionCertificate();
  const existing = await squadquestProfiles();

  const bundleRes = await requestAll(
    `/v1/bundleIds?filter%5Bidentifier%5D=${encodeURIComponent(APP_BUNDLE_ID)}&limit=200`,
  );
  const bundleIdResources = new Map(
    (Array.isArray(bundleRes.data) ? bundleRes.data : []).map((b) => [
      b.attributes?.identifier as string,
      b.id,
    ]),
  );

  const results = [];
  for (const bundleId of targets) {
    const name = PROFILE_NAMES[bundleId]!;
    const resourceId = bundleIdResources.get(bundleId);
    if (!resourceId) {
      throw new AxiError(`Bundle id ${bundleId} is not registered`, "bundle-id-not-found");
    }

    for (const { resource, bundleId: existingBundle } of existing) {
      if (existingBundle === bundleId && resource.attributes?.profileType === APP_STORE_PROFILE) {
        await request("DELETE", `/v1/profiles/${resource.id}`);
      }
    }

    const created = await request("POST", "/v1/profiles", {
      data: {
        type: "profiles",
        attributes: { name, profileType: APP_STORE_PROFILE },
        relationships: {
          bundleId: { data: { id: resourceId, type: "bundleIds" } },
          certificates: { data: [{ id: cert.id, type: "certificates" }] },
        },
      },
    });

    const attrs = (created.data as AscResource).attributes ?? {};
    results.push({
      name: attrs.name,
      bundleId,
      state: attrs.profileState,
      expires: (attrs.expirationDate ?? "").slice(0, 10),
    });
  }

  return {
    regenerated: results,
    certificate: cert.attributes?.name,
    note: "Names are unchanged, so ExportOptions.plist and the workflow need no edit",
  };
}

export async function certsList() {
  const res = await requestAll("/v1/certificates?limit=200");
  const rows = (Array.isArray(res.data) ? res.data : [])
    .map((c) => ({
      name: c.attributes?.name,
      type: c.attributes?.certificateType,
      expires: (c.attributes?.expirationDate ?? "").slice(0, 10),
      daysLeft: daysUntil(c.attributes?.expirationDate),
    }))
    .sort((a, b) => (a.daysLeft ?? 0) - (b.daysLeft ?? 0));

  const expiring = rows.filter(
    (r) => r.type === "DISTRIBUTION" && (r.daysLeft ?? 999) < 60,
  );

  return {
    certificates: rows,
    ...(expiring.length
      ? {
          attention: expiring.map(
            (r) =>
              `${r.name} expires in ${r.daysLeft} days — re-export the .p12 and update APPLE_CERTIFICATE_BASE64, then regenerate profiles`,
          ),
        }
      : {}),
  };
}

export async function devicesList() {
  const res = await requestAll("/v1/devices?limit=200");
  const rows = (Array.isArray(res.data) ? res.data : [])
    .filter((d) => d.attributes?.status === "ENABLED")
    .map((d) => ({
      name: d.attributes?.name,
      platform: d.attributes?.platform,
      udid: d.attributes?.udid,
    }));

  return { devices: rows, count: rows.length };
}

export async function devicesAdd(args: string[]) {
  const [name, udid] = args;
  if (!name || !udid) throw new AxiError("Usage: devices add <name> <udid>", "usage");

  const res = await request("POST", "/v1/devices", {
    data: {
      type: "devices",
      attributes: { name, udid, platform: "IOS" },
    },
  });

  const attrs = (res.data as AscResource).attributes ?? {};
  return {
    added: { name: attrs.name, udid: attrs.udid, status: attrs.status },
    help: [
      `Run \`${cliInvocation()} profiles regenerate\` so development profiles pick up the new device`,
    ],
  };
}
