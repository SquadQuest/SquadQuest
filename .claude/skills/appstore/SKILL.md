---
name: appstore
description: >-
  Drive SquadQuest's iOS release on App Store Connect — create an App Store version, set
  What's New, attach a TestFlight build, submit for review, release an approved build — and
  maintain the signing assets CI can't touch (provisioning profiles, distribution
  certificates, devices). Use this whenever iOS shipping comes up: "submit to the App Store",
  "what's the app store status", "is 1.46 approved yet", "push the build to review", "the iOS
  build is failing to sign", "the provisioning profile expired", "add my phone as a test
  device", "why is TestFlight still on the old build". Also use it right after a v1 release
  ships, since /v1-release stops at TestFlight and the App Store half starts here. Reach for
  it before hand-rolling curl against api.appstoreconnect.apple.com or clicking through the
  App Store Connect web UI.
---

# App Store Connect for SquadQuest

The GitHub release workflow builds and uploads iOS to TestFlight. Everything after that —
turning a TestFlight build into a version on sale — happens here.

Division of labour, so you reach for the right thing:

| `/v1-release` | this skill |
| --- | --- |
| Cuts the GitHub Release; workflow ships web, Play Store, TestFlight | Takes a TestFlight build to the App Store |
| Stops when the build finishes processing | Starts there |

The CLI is `scripts/appstore`, bundled with this skill. Run it with no arguments for live
state; it's the fastest way to know where a release actually stands.

## Credentials

Auth is an App Store Connect **team** API key, read from `~/.appstoreconnect/private_keys/`:

- `AuthKey_<id>.p8` — the key, `chmod 600`. The key id comes from the filename, so there's
  nothing to keep in sync.
- `issuer_id` — the team's issuer id, or set `APPSTORE_ISSUER_ID`.

This is Apple's own convention, so `xcodebuild` and fastlane find the same key. It is
deliberately **not** the key CI uses: CI holds a narrower App Manager key that can read
signing assets and upload builds but cannot create profiles or certificates. The key here is
Admin, which is why profile repair lives in this skill and not in the workflow.

If a command fails with a permission error, that's usually the distinction biting — check
which key is in play before assuming the API is broken.

<!-- BEGIN GENERATED: command-reference -->

### Release

- `scripts/appstore builds [--limit <n>]` — Recent TestFlight builds with processing state
- `scripts/appstore version list [--limit <n>]` — App Store versions and where each one sits
- `scripts/appstore version create <version>` — Start a new App Store version (e.g. 1.47.0)
- `scripts/appstore version show <version>` — One version in full: state, build, notes, release type
- `scripts/appstore notes set <version> --file <path> | --text <s> | --from-release <tag>` — Set What's New, reusing the GitHub release notes when given a tag
- `scripts/appstore build attach <version> <build>` — Bind a processed TestFlight build to a version
- `scripts/appstore submit <version>` — Submit for App Store review (asks first)
- `scripts/appstore release <version>` — Release a version that is approved and waiting (asks first)

### Signing assets

- `scripts/appstore profiles list` — Provisioning profiles for both bundle ids, with expiry
- `scripts/appstore profiles regenerate [--bundle-id <id>]` — Recreate profiles after expiry or a device change
- `scripts/appstore certs list` — Signing certificates and when they expire
- `scripts/appstore devices list` — Registered devices
- `scripts/appstore devices add <name> <udid>` — Register a device for development builds

### Session

- `scripts/appstore home` — Identity and quick reference (the session-start view)
- `scripts/appstore hook install|uninstall|status [--global]` — Manage the SessionStart hook

<!-- END GENERATED: command-reference -->

## Shipping a release

The order matters: a version can't be submitted without a build attached, and a build can't
be attached until Apple finishes processing it.

```bash
scripts/appstore                                 # what's live, what's in flight, latest build
scripts/appstore builds                          # find the build number, confirm state is VALID
scripts/appstore version create 1.47.0
scripts/appstore notes set 1.47.0 --from-release v1.47.0
scripts/appstore build attach 1.47.0 203
scripts/appstore submit 1.47.0                   # shows what it would send
scripts/appstore submit 1.47.0 --yes             # actually submits
```

`notes set --from-release` pulls the `## What's New` section straight out of the GitHub
release that `/v1-release` wrote. Reusing it keeps the App Store, the Play Store and the
release page saying the same thing, and saves rewriting bullets that already exist. Use
`--file` or `--text` when the App Store needs different wording.

Two commands reach the outside world and won't act without `--yes`:

- **`submit`** — you can cancel a submission, but Apple sees the attempt, and repeated
  cancels are a bad look. Without `--yes` it prints the version, its state and the
  localizations it would send, so there's a real chance to check before committing.
- **`release`** — only meaningful for a version approved and held for manual release. It
  puts the app on sale immediately.

Treat both the way you'd treat publishing a GitHub release: confirm with the user first,
even if they asked for the release generally. "Submit it" is authorization to run `submit`;
it isn't standing authorization to also `release` once Apple approves.

## When the build won't sign

The release workflow signs with **manual** profiles pinned per bundle id in
`ios/ExportOptions.plist`, downloaded fresh each build. That means signing breaks in exactly
two ways, and both show up here:

```bash
scripts/appstore profiles list    # state and days remaining for both bundle ids
scripts/appstore certs list       # certificate expiry
```

**A profile expired or went invalid.** `profiles regenerate` deletes and recreates it —
Apple has no renew. The names stay the same, which is the point: `ExportOptions.plist` pins
profiles *by name*, so a regenerated profile needs no repo change.

**The distribution certificate expired.** Regenerating profiles isn't enough, because
profiles embed the certificate. Re-export the `.p12` from Keychain Access, update the
`APPLE_CERTIFICATE_BASE64` and `APPLE_CERTIFICATE_PASSWORD` GitHub secrets, *then*
regenerate profiles so they reference the new cert.

SquadQuest signs two bundle ids — `app.squadquest` and the `app.squadquest.ImageNotification`
notification extension. A missing profile for either one fails the export, and the extension
is easy to forget because nothing references it by name in day-to-day work.

## Reading the output

Every command returns structured output. A few conventions worth knowing:

- `attention` means something needs a human decision — an expiring profile, a certificate
  about to lapse. It only appears when there's genuinely something to act on.
- `help` lines are runnable commands with resolved paths. Suggest them as-is.
- Errors carry a `code` and suggestions. A `403` almost always means the key's role is too
  narrow rather than that the request was malformed.

## Things that will surprise you

**Build numbers come from the tag count**, not from App Store Connect. The release workflow
computes `git ls-remote | grep -c 'refs/tags/v[01]\.'`, so the same tag always produces the
same build number — and TestFlight rejects a duplicate. Re-running a build for a tag that
already uploaded will fail at the upload step; that's working as intended, not a bug.

**Processing takes minutes.** A freshly uploaded build shows `PROCESSING` and can't be
attached until it's `VALID`. `build attach` refuses rather than failing obscurely later.

**Agreements block submission.** If Apple posts a new developer agreement, submission fails
until someone accepts it in the web UI. No API can clear that, so when a submission fails
for a reason that looks like nothing to do with the build, check App Store Connect directly.

## Keeping the CLI in sync

Source lives in `tools/appstore/`; the committed bundle here is generated.

```bash
cd tools/appstore && bun install && bun run build
```

`reference.ts` is the single source of truth for the command surface — the help text and the
generated region of this file both derive from it, so adding a command means editing
`reference.ts` and wiring it in `cli.ts`. Never edit `scripts/appstore.mjs` directly;
`bun run check` fails if the committed bundle or this file is stale.
