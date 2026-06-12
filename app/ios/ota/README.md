# iOS OTA dev build — setup

The `v2-ipa` job in `.github/workflows/v2-publish.yml` builds the **SquadQuest Dev** ad-hoc IPA
and publishes an OTA install page to `https://v2.squadquest.app/downloads/`. It stays **off**
until you complete the Apple-side setup below and flip the gate.

Spec: [`specs/behaviors/ci-cd.md`](../../../specs/behaviors/ci-cd.md) → "iOS OTA (ad-hoc) publishing".

## One-time Apple Developer portal setup

1. **App ID** — register `app.squadquest.dev` (Identifiers → App IDs).
2. **Devices** — add each tester's **UDID** (Devices). Re-do step 3 whenever you add one.
3. **Provisioning profile** — create an **Ad Hoc** distribution profile named exactly
   **`SquadQuest Dev Ad Hoc`**, for App ID `app.squadquest.dev`, selecting the devices from (2)
   and your distribution certificate.
4. **Distribution certificate** — if you don't have one, create an Apple Distribution cert and
   export it (with its private key) as a `.p12` with a password.

## Repo secrets (Settings → Secrets and variables → Actions → Secrets)

| Secret | How to produce |
|---|---|
| `APPLE_CERTIFICATE_BASE64` | `base64 -i dist-cert.p12 \| pbcopy` |
| `APPLE_CERTIFICATE_PASSWORD` | the `.p12` export password |
| `APPLE_PROVISIONING_PROFILE_BASE64` | `base64 -i SquadQuest_Dev_Ad_Hoc.mobileprovision \| pbcopy` |
| `APPLE_TEAM_ID` | your 10-char Team ID (e.g. from the profile or membership page) |

## Enable the job (Settings → Secrets and variables → Actions → Variables)

Set repo **variable** `IOS_PUBLISH_ENABLED` = `true`. The next push to `develop` runs `v2-ipa`.

## Result

- Install page: **<https://v2.squadquest.app/downloads/>** (open in Safari **on the iPhone**).
- The page's "Install on this iPhone" button is an `itms-services://` OTA link → the device must
  be in the provisioning profile, and Developer Mode must be enabled on first launch.
- Build-numbered IPA + `squadquest-dev-latest.ipa` are co-hosted next to `manifest.plist`.
