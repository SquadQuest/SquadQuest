---
status: in-progress
depends: [v2-ci-cd-pipelines]
specs:
  - specs/behaviors/ci-cd.md
issues: []
pr: 452
---

# Plan: v2 iOS OTA (ad-hoc) dev build publishing

> Mirror the dev-APK pipeline for iOS: build a signed ad-hoc IPA on every develop push and
> publish an OTA install page to `v2.squadquest.app/downloads/`, modeled on the
> `pathways-field-companion` setup (itms-services manifest + co-hosted IPA). Gated off until the
> Apple signing prerequisites are configured.

## Scope

**In:**

- `v2-ipa` job in `v2-publish.yml` (macOS runner): retarget Runner → `app.squadquest.dev` /
  "SquadQuest Dev" at build time (iOS has no committed flavor), install Apple cert + ad-hoc
  profile, `flutter build ipa` (pointed at prod), publish IPA (`-b<N>` + `-latest`),
  `manifest.plist`, and `index.html` under `downloads/`.
- `ios/ExportOptions-dev.plist` (ad-hoc, manual; team id substituted from secret).
- `ios/ota/manifest.plist` + `ios/ota/index.html` (OTA install page; `__BUILD_VERSION__` stamped
  by CI) + `ios/ota/README.md` (Apple-side setup checklist).
- Spec: iOS OTA subsection in `behaviors/ci-cd.md`.
- **Gate:** `if: vars.IOS_PUBLISH_ENABLED == 'true'` so the paid macOS runner is skipped until
  signing is set up.

**Out:** App Store / TestFlight; a proper iOS xcconfig flavor (CI-time retarget for now); iOS
branch previews; automatic UDID registration.

## Implements

`specs/behaviors/ci-cd.md` (iOS OTA section). Reuses the `downloads/` path + v2-bucket write the
APK job established — no new infra/IAM.

## Approach

CI-time identity retarget (`sed` the pbxproj bundle id + PlistBuddy the display name) avoids
committing an iOS flavor now; the IPA is co-hosted next to the manifest so the OTA
`software-package` URL is a direct HTTPS download (OTA breaks on redirects), which the LB serves.

## Validation

- [x] Workflow YAML valid; templates committed; spec documents the pipeline + setup prereqs.
- [ ] **(blocked on user)** Apple setup: register `app.squadquest.dev`, create "SquadQuest Dev
      Ad Hoc" profile with tester UDIDs, load 4 secrets, set `IOS_PUBLISH_ENABLED=true`.
- [ ] **(post-enable)** develop push builds + signs the IPA; `manifest.plist` + IPA + install page
      land under `downloads/`; OTA install works on a registered device from Safari.

## Risks / unknowns

- CI-time pbxproj rewrite is brittle if the project layout changes — a real xcconfig flavor is the
  durable fix (deferred). The `sed` targets only `= app.squadquest;` so RunnerTests
  (`app.squadquest.RunnerTests`) are untouched; re-verify if bundle ids change.
- OTA is unforgiving: manifest URL must be direct HTTPS (no 302), install must happen in real
  Safari on-device, device must be in the profile, Developer Mode on. The install page documents
  all four.
- macOS runner minutes are billable — the gate keeps it off until intentionally enabled.

## Notes

(closeout)

## Follow-ups

(closeout)
