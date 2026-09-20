/**
 * Home view — what a session sees on start.
 *
 * This runs on every SessionStart, so it has to be cheap and it must never
 * fail the session. When there are no credentials (a fresh clone, CI, a
 * machine without the key) it degrades to identity plus setup guidance rather
 * than erroring, because a broken hook is worse than an uninformative one.
 */
import { APP_BUNDLE_ID, getApp, request, requestAll, KEY_DIR } from "../asc.js";
import { cliInvocation } from "../invocation.js";
import { COMMAND_GROUPS, DESCRIPTION } from "../reference.js";
import { RELEASE_PROFILE_NAMES } from "./signing.js";

function helpLines(): string[] {
  const cli = cliInvocation();
  return [
    `Run \`${cli} builds\` to see recent TestFlight builds`,
    `Run \`${cli} version list\` to see App Store versions and their state`,
    `Run \`${cli} profiles list\` to check signing assets before a release`,
    `Run \`${cli} --help\` for the full command list`,
  ];
}

/**
 * Live state, but only the few facts that tell you whether a release is in
 * flight and whether signing is about to break. Anything more belongs behind
 * an explicit command.
 */
async function liveState() {
  const app = await getApp();

  const [versionsRes, buildsRes, profilesRes] = await Promise.all([
    request("GET", `/v1/apps/${app.id}/appStoreVersions?limit=3`),
    request("GET", `/v1/builds?filter%5Bapp%5D=${app.id}&sort=-version&limit=1`),
    requestAll("/v1/profiles?limit=200"),
  ]);

  const versions = Array.isArray(versionsRes.data) ? versionsRes.data : [];
  const live = versions.find((v) => v.attributes?.appStoreState === "READY_FOR_SALE");
  const inFlight = versions.find((v) => v.attributes?.appStoreState !== "READY_FOR_SALE");
  const latestBuild = (Array.isArray(buildsRes.data) ? buildsRes.data : [])[0];

  // Only the App Store profiles the release build actually pins. A stale
  // development profile is noise here -- it can't break a release.
  const expiringSoon = (Array.isArray(profilesRes.data) ? profilesRes.data : [])
    .filter((p) => RELEASE_PROFILE_NAMES.includes(p.attributes?.name ?? ""))
    .filter((p) => {
      const days = (new Date(p.attributes?.expirationDate ?? 0).getTime() - Date.now()) / 86_400_000;
      return p.attributes?.profileState !== "ACTIVE" || days < 30;
    })
    .map((p) => p.attributes?.name);

  return {
    app: {
      name: app.attributes?.name,
      bundleId: APP_BUNDLE_ID,
      live: live?.attributes?.versionString ?? "—",
    },
    ...(inFlight
      ? {
          inFlight: {
            version: inFlight.attributes?.versionString,
            state: inFlight.attributes?.appStoreState,
          },
        }
      : {}),
    ...(latestBuild
      ? {
          latestBuild: {
            build: latestBuild.attributes?.version,
            state: latestBuild.attributes?.processingState,
          },
        }
      : {}),
    ...(expiringSoon.length ? { signingAttention: expiringSoon } : {}),
  };
}

export async function home() {
  let state: Record<string, unknown>;
  try {
    state = await liveState();
  } catch (error) {
    // No key, no network, expired token — say so plainly and keep going.
    state = {
      status: "not configured",
      detail: error instanceof Error ? error.message : String(error),
      setup: [
        `Put a team API key at ${KEY_DIR}/AuthKey_<id>.p8 (chmod 600)`,
        `Set APPSTORE_ISSUER_ID, or write it to ${KEY_DIR}/issuer_id`,
      ],
    };
  }

  return { description: DESCRIPTION, ...state, help: helpLines() };
}

/** The SessionStart payload. Same content as home; kept separate so the hook
 * can be tuned independently of what a human typing `appstore` sees. */
export async function hookPayload() {
  return home();
}

export function topLevelHelp(): string {
  const lines: string[] = [DESCRIPTION, "", "Commands:"];
  for (const group of COMMAND_GROUPS) {
    lines.push("", `  ${group.group}:`);
    for (const c of group.commands) {
      lines.push(`    ${c.usage.padEnd(52)} ${c.summary}`);
    }
  }
  lines.push("", `Invoke as: ${cliInvocation()} <command>`);
  return lines.join("\n");
}
