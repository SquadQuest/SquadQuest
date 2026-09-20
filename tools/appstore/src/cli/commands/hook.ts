/**
 * SessionStart hook management.
 *
 * Project scope is the default: this CLI is specific to SquadQuest's App Store
 * presence, so it belongs in the repo's .claude/settings.json rather than every
 * session on the machine. --global is there for a maintainer who wants the
 * release state visible everywhere.
 */
import { AxiError, installSessionStartHooks, sessionStartHookStatus, uninstallSessionStartHooks } from "axi-sdk-js";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import { cliInvocation } from "../invocation.js";

const MARKER = "squadquest-appstore";

/**
 * Project dir is the repo root, three levels up from the bundle
 * (.claude/skills/appstore/scripts/appstore.mjs). Resolved from the bundle
 * rather than cwd so installing works from anywhere in the tree.
 */
function projectDir(): string {
  const bundle = fileURLToPath(import.meta.url);
  return resolve(dirname(bundle), "..", "..", "..", "..");
}

function scopeOf(args: string[]) {
  return args.includes("--global")
    ? ({ scope: "user" as const } as const)
    : ({ scope: "project" as const, projectDir: projectDir() } as const);
}

export async function hook(args: string[]) {
  const action = args[0];
  const scope = scopeOf(args);
  const execPath = cliInvocation().replace(/^node /, "").replace(/^~/, process.env.HOME ?? "~");

  if (action === "install") {
    installSessionStartHooks({ marker: MARKER, execPath, ...scope });
    return {
      installed: { marker: MARKER, scope: scope.scope },
      note: "New sessions will show the App Store view on start",
    };
  }

  if (action === "uninstall") {
    uninstallSessionStartHooks({ marker: MARKER, execPath, ...scope });
    return { uninstalled: { marker: MARKER, scope: scope.scope } };
  }

  if (action === "status" || action === undefined) {
    const status = sessionStartHookStatus({ marker: MARKER, execPath, ...scope });
    return {
      hook: {
        marker: status.marker,
        scope: status.scope,
        claude: status.claude.installed,
        path: status.claude.path,
      },
      help: [`Run \`${cliInvocation()} hook install\` to enable it for this repo`],
    };
  }

  throw new AxiError(`Unknown hook action '${action}'`, "unknown-hook-action", [
    "Use install, uninstall or status",
  ]);
}
