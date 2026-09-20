/**
 * Single source of truth for the command surface.
 *
 * The home view's help, `--help`, and the generated region of SKILL.md all
 * derive from this, so the documentation cannot drift from the implementation.
 * Adding a command here and wiring it in cli.ts is the whole change.
 */
export const DESCRIPTION =
  "Drive SquadQuest's App Store Connect releases and signing assets — version, notes, build, review submission, profiles, certs";

export interface CommandGroup {
  group: string;
  commands: Array<{ usage: string; summary: string }>;
}

export const COMMAND_GROUPS: CommandGroup[] = [
  {
    group: "Release",
    commands: [
      {
        usage: "builds [--limit <n>]",
        summary: "Recent TestFlight builds with processing state",
      },
      {
        usage: "version list [--limit <n>]",
        summary: "App Store versions and where each one sits",
      },
      {
        usage: "version create <version>",
        summary: "Start a new App Store version (e.g. 1.47.0)",
      },
      {
        usage: "version show <version>",
        summary: "One version in full: state, build, notes, release type",
      },
      {
        usage: "notes set <version> --file <path> | --text <s> | --from-release <tag>",
        summary: "Set What's New, reusing the GitHub release notes when given a tag",
      },
      {
        usage: "build attach <version> <build>",
        summary: "Bind a processed TestFlight build to a version",
      },
      {
        usage: "submit <version>",
        summary: "Submit for App Store review (asks first)",
      },
      {
        usage: "release <version>",
        summary: "Release a version that is approved and waiting (asks first)",
      },
    ],
  },
  {
    group: "Signing assets",
    commands: [
      {
        usage: "profiles list",
        summary: "Provisioning profiles for both bundle ids, with expiry",
      },
      {
        usage: "profiles regenerate [--bundle-id <id>]",
        summary: "Recreate profiles after expiry or a device change",
      },
      { usage: "certs list", summary: "Signing certificates and when they expire" },
      { usage: "devices list", summary: "Registered devices" },
      {
        usage: "devices add <name> <udid>",
        summary: "Register a device for development builds",
      },
    ],
  },
  {
    group: "Session",
    commands: [
      { usage: "home", summary: "Identity and quick reference (the session-start view)" },
      {
        usage: "hook install|uninstall|status [--global]",
        summary: "Manage the SessionStart hook",
      },
    ],
  },
];
