/**
 * The App Store version lifecycle: builds -> version -> notes -> attach ->
 * submit -> release.
 *
 * Submitting and releasing are the two steps that reach the outside world and
 * can't be quietly undone, so both refuse to act without --yes. Everything
 * before them is freely reversible, so they just do the thing.
 */
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { AxiError } from "axi-sdk-js";
import { getApp, request, requestAll, type AscResource } from "../asc.js";
import { cliInvocation } from "../invocation.js";

const PLATFORM = "IOS";

function flag(args: string[], name: string): string | undefined {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1] : undefined;
}

function has(args: string[], name: string): boolean {
  return args.includes(`--${name}`);
}

/** Builds newest-first, with the processing state that gates attaching. */
export async function builds(args: string[]) {
  const app = await getApp();
  const limit = Number(flag(args, "limit") ?? 10);
  const res = await request(
    "GET",
    `/v1/builds?filter%5Bapp%5D=${app.id}&sort=-version&limit=${Math.min(limit, 200)}`,
  );

  const rows = (Array.isArray(res.data) ? res.data : []).map((b) => ({
    build: b.attributes?.version,
    state: b.attributes?.processingState,
    expired: b.attributes?.expired ? "yes" : "no",
    uploaded: (b.attributes?.uploadedDate ?? "").slice(0, 16).replace("T", " "),
  }));

  if (rows.length === 0) {
    return {
      builds: [],
      note: "No builds found. Publish a release, or run the workflow with upload_to_testflight enabled.",
    };
  }

  return {
    builds: rows,
    help: [
      `Run \`${cliInvocation()} build attach <version> <build>\` to bind one to a version`,
    ],
  };
}

async function versions(appId: string, limit = 20) {
  return requestAll(
    `/v1/apps/${appId}/appStoreVersions?limit=${Math.min(limit, 200)}&include=build`,
  );
}

export async function versionList(args: string[]) {
  const app = await getApp();
  const limit = Number(flag(args, "limit") ?? 10);
  const res = await versions(app.id, limit);
  const builds = new Map(
    (res.included ?? []).filter((i) => i.type === "builds").map((b) => [b.id, b]),
  );

  const all = Array.isArray(res.data) ? res.data : [];
  const rows = all.slice(0, limit).map((v) => ({
    version: v.attributes?.versionString,
    state: v.attributes?.appStoreState,
    release: v.attributes?.releaseType,
    build:
      builds.get(v.relationships?.build?.data?.id ?? "")?.attributes?.version ?? "—",
  }));

  return { versions: rows, ...(all.length > rows.length ? { total: all.length } : {}) };
}

async function findVersion(appId: string, versionString: string): Promise<AscResource> {
  const res = await versions(appId, 200);
  const match = (Array.isArray(res.data) ? res.data : []).find(
    (v) => v.attributes?.versionString === versionString,
  );
  if (!match) {
    throw new AxiError(`No App Store version ${versionString}`, "version-not-found", [
      `Run \`${cliInvocation()} version list\` to see what exists`,
      `Run \`${cliInvocation()} version create ${versionString}\` to start it`,
    ]);
  }
  return match;
}

export async function versionShow(args: string[]) {
  const versionString = args[0];
  if (!versionString) throw new AxiError("Usage: version show <version>", "usage");

  const app = await getApp();
  const version = await findVersion(app.id, versionString);

  const locRes = await request(
    "GET",
    `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=50`,
  );
  const locales = (Array.isArray(locRes.data) ? locRes.data : []).map((l) => ({
    locale: l.attributes?.locale,
    whatsNew: (l.attributes?.whatsNew ?? "").split("\n")[0]?.slice(0, 60) ?? "",
  }));

  let build = "—";
  const buildId = version.relationships?.build?.data?.id;
  if (buildId) {
    const b = await request("GET", `/v1/builds/${buildId}`);
    build = (b.data as AscResource)?.attributes?.version ?? "—";
  }

  return {
    version: {
      version: version.attributes?.versionString,
      state: version.attributes?.appStoreState,
      releaseType: version.attributes?.releaseType,
      build,
    },
    localizations: locales,
  };
}

export async function versionCreate(args: string[]) {
  const versionString = args[0];
  if (!versionString) throw new AxiError("Usage: version create <version>", "usage");

  const app = await getApp();
  const res = await request("POST", "/v1/appStoreVersions", {
    data: {
      type: "appStoreVersions",
      attributes: { platform: PLATFORM, versionString },
      relationships: { app: { data: { id: app.id, type: "apps" } } },
    },
  });

  const created = res.data as AscResource;
  return {
    created: {
      version: created.attributes?.versionString,
      state: created.attributes?.appStoreState,
    },
    help: [
      `Run \`${cliInvocation()} notes set ${versionString} --from-release v${versionString}\` to fill What's New`,
    ],
  };
}

/**
 * Reuse the GitHub release notes rather than retyping them. /v1-release already
 * writes a "## What's New" section for the Play Store, and the same bullets are
 * what App Store reviewers and users should see.
 */
function notesFromRelease(tag: string): string {
  let body: string;
  try {
    body = execFileSync(
      "gh",
      ["release", "view", tag, "--repo", "SquadQuest/SquadQuest", "--json", "body", "--jq", ".body"],
      { encoding: "utf8" },
    );
  } catch {
    throw new AxiError(`Couldn't read release ${tag}`, "release-not-found", [
      "Check the tag exists and gh is authenticated",
    ]);
  }

  const lines = body.split("\n");
  const start = lines.findIndex((l) => /^##\s+What'?s New/i.test(l));
  if (start === -1) {
    throw new AxiError(`Release ${tag} has no "## What's New" section`, "no-whats-new", [
      "Pass --file or --text instead",
    ]);
  }
  const rest = lines.slice(start + 1);
  const end = rest.findIndex((l) => /^##\s/.test(l));
  return (end === -1 ? rest : rest.slice(0, end)).join("\n").trim();
}

export async function notesSet(args: string[]) {
  const versionString = args[0];
  if (!versionString) throw new AxiError("Usage: notes set <version> [source]", "usage");

  const file = flag(args, "file");
  const text = flag(args, "text");
  const fromRelease = flag(args, "from-release");

  let whatsNew: string;
  if (fromRelease) whatsNew = notesFromRelease(fromRelease);
  else if (file) whatsNew = readFileSync(file, "utf8").trim();
  else if (text) whatsNew = text;
  else {
    throw new AxiError("Need one of --file, --text or --from-release", "usage", [
      `Run \`${cliInvocation()} notes set ${versionString} --from-release v${versionString}\` to reuse the GitHub release notes`,
    ]);
  }

  if (whatsNew.length > 4000) {
    throw new AxiError(
      `What's New is ${whatsNew.length} characters; the App Store allows 4000`,
      "notes-too-long",
    );
  }

  const app = await getApp();
  const version = await findVersion(app.id, versionString);
  const locRes = await request(
    "GET",
    `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=50`,
  );

  const updated: string[] = [];
  for (const loc of Array.isArray(locRes.data) ? locRes.data : []) {
    await request("PATCH", `/v1/appStoreVersionLocalizations/${loc.id}`, {
      data: { id: loc.id, type: "appStoreVersionLocalizations", attributes: { whatsNew } },
    });
    updated.push(loc.attributes?.locale);
  }

  return { version: versionString, locales: updated, characters: whatsNew.length };
}

export async function buildAttach(args: string[]) {
  const [versionString, buildNumber] = args;
  if (!versionString || !buildNumber) {
    throw new AxiError("Usage: build attach <version> <build>", "usage");
  }

  const app = await getApp();
  const version = await findVersion(app.id, versionString);

  const res = await request(
    "GET",
    `/v1/builds?filter%5Bapp%5D=${app.id}&filter%5Bversion%5D=${encodeURIComponent(buildNumber)}&limit=10`,
  );
  const build = (Array.isArray(res.data) ? res.data : [])[0];
  if (!build) {
    throw new AxiError(`No build ${buildNumber}`, "build-not-found", [
      `Run \`${cliInvocation()} builds\` to see what has been uploaded`,
    ]);
  }

  const state = build.attributes?.processingState;
  if (state !== "VALID") {
    throw new AxiError(`Build ${buildNumber} is ${state}, not VALID`, "build-not-ready", [
      "Apple is still processing it — wait and try again",
    ]);
  }

  await request("PATCH", `/v1/appStoreVersions/${version.id}/relationships/build`, {
    data: { id: build.id, type: "builds" },
  });

  return {
    attached: { version: versionString, build: buildNumber },
    help: [`Run \`${cliInvocation()} submit ${versionString}\` when the metadata is ready`],
  };
}

/**
 * Submission is the point of no return in practice — you can cancel, but the
 * attempt is visible to Apple and repeated cancels look bad. So this refuses
 * without --yes and prints exactly what would be sent.
 */
export async function submit(args: string[]) {
  const versionString = args[0];
  if (!versionString) throw new AxiError("Usage: submit <version> [--yes]", "usage");

  const app = await getApp();
  const version = await findVersion(app.id, versionString);

  if (!has(args, "yes")) {
    const detail = await versionShow([versionString]);
    return {
      wouldSubmit: detail.version,
      localizations: detail.localizations,
      confirm: `Re-run with --yes to submit ${versionString} for App Store review`,
    };
  }

  const sub = await request("POST", "/v1/reviewSubmissions", {
    data: {
      type: "reviewSubmissions",
      attributes: { platform: PLATFORM },
      relationships: { app: { data: { id: app.id, type: "apps" } } },
    },
  });
  const submissionId = (sub.data as AscResource).id;

  await request("POST", "/v1/reviewSubmissionItems", {
    data: {
      type: "reviewSubmissionItems",
      relationships: {
        reviewSubmission: { data: { id: submissionId, type: "reviewSubmissions" } },
        appStoreVersion: { data: { id: version.id, type: "appStoreVersions" } },
      },
    },
  });

  await request("PATCH", `/v1/reviewSubmissions/${submissionId}`, {
    data: { id: submissionId, type: "reviewSubmissions", attributes: { submitted: true } },
  });

  return {
    submitted: { version: versionString, submissionId },
    note: "Apple will email as review progresses; check state with `version show`",
  };
}

export async function releaseVersion(args: string[]) {
  const versionString = args[0];
  if (!versionString) throw new AxiError("Usage: release <version> [--yes]", "usage");

  const app = await getApp();
  const version = await findVersion(app.id, versionString);
  const state = version.attributes?.appStoreState;

  if (!has(args, "yes")) {
    return {
      wouldRelease: { version: versionString, state },
      confirm: `Re-run with --yes to release ${versionString} to the App Store`,
    };
  }

  if (state !== "PENDING_DEVELOPER_RELEASE") {
    throw new AxiError(
      `Version ${versionString} is ${state}, not waiting for release`,
      "not-releasable",
      ["Only an approved version held for manual release can be released this way"],
    );
  }

  await request("POST", "/v1/appStoreVersionReleaseRequests", {
    data: {
      type: "appStoreVersionReleaseRequests",
      relationships: {
        appStoreVersion: { data: { id: version.id, type: "appStoreVersions" } },
      },
    },
  });

  return { released: { version: versionString } };
}
