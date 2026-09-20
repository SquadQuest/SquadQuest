/**
 * Command registry and CLI wiring.
 *
 * Subcommands ("version create", "profiles list") are dispatched here by
 * consuming the first arg, because runAxiCli's registry is flat. Keeping that
 * dispatch in one place means reference.ts stays the only description of the
 * surface.
 */
import { runAxiCli, AxiError } from "axi-sdk-js";
import { DESCRIPTION } from "./reference.js";
import { home, hookPayload, topLevelHelp } from "./commands/home.js";
import { hook } from "./commands/hook.js";
import {
  buildAttach,
  builds,
  notesSet,
  releaseVersion,
  submit,
  versionCreate,
  versionList,
  versionShow,
} from "./commands/release.js";
import {
  certsList,
  devicesAdd,
  devicesList,
  profilesList,
  profilesRegenerate,
} from "./commands/signing.js";

declare const __APPSTORE_VERSION__: string;
const VERSION = typeof __APPSTORE_VERSION__ === "string" ? __APPSTORE_VERSION__ : "dev";

type Handler = (args: string[]) => Promise<unknown> | unknown;

/** Dispatch `<group> <action>` against a table, with a usable error otherwise. */
function group(name: string, actions: Record<string, Handler>): Handler {
  return (args: string[]) => {
    const action = args[0];
    const handler = action ? actions[action] : undefined;
    if (!handler) {
      throw new AxiError(
        action ? `Unknown ${name} action '${action}'` : `${name} needs an action`,
        `unknown-${name}-action`,
        [`Available: ${Object.keys(actions).join(", ")}`],
      );
    }
    return handler(args.slice(1));
  };
}

export async function main(argv = process.argv.slice(2)): Promise<void> {
  await runAxiCli({
    description: DESCRIPTION,
    version: VERSION,
    argv,
    topLevelHelp: topLevelHelp(),
    home: () => home(),
    commands: {
      home: () => home(),
      hook: (args) => hook(args),

      builds: (args) => builds(args),
      version: group("version", {
        list: versionList,
        create: versionCreate,
        show: versionShow,
      }),
      notes: group("notes", { set: notesSet }),
      build: group("build", { attach: buildAttach }),
      submit: (args) => submit(args),
      release: (args) => releaseVersion(args),

      profiles: group("profiles", {
        list: () => profilesList(),
        regenerate: profilesRegenerate,
      }),
      certs: group("certs", { list: () => certsList() }),
      devices: group("devices", { list: () => devicesList(), add: devicesAdd }),
    },
  } as Parameters<typeof runAxiCli>[0]);
}
