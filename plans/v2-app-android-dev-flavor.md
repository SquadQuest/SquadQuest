---
status: done
depends: []
specs:
  - specs/architecture.md
issues: []
pr: 445
---

# Plan: v2 android dev/prod build flavors

> Authored retroactively at `done` to give the dev-flavor work (shipped in PR #445) a real home
> in the DAG — `v2-ci-cd-pipelines` depends on it (the APK job builds the `dev` flavor).

## Scope

Give Android milestone builds a distinct identity from the store build so a sideloaded debug APK
installs alongside SquadQuest v1 instead of colliding with it.

**In (shipped):** a `channel` flavor dimension — `prod` (`app.squadquest`, "SquadQuest", the
preserved v1 store id) and `dev` (`app.squadquest.dev`, "SquadQuest Dev", sideload-alongside).
Main-manifest label parameterized to `${appLabel}` per flavor. Android only.

**Out:** iOS flavor schemes (deferred); release-keystore signing (dev stays debug-signed).

## Implements

`specs/architecture.md` "Build channels (flavors)" section. Android `build.gradle.kts` flavor
config + manifest label placeholder.

## Validation

- [x] `assembleDevRelease` → APK reports `app.squadquest.dev`, label "SquadQuest Dev",
      debug-signed, prod API + android client header baked in.
- [x] `prod` flavor unchanged (`app.squadquest`).
- [x] CI unaffected (analyze/test/build-web — no flavorless android build).

## Risks / unknowns

(resolved — see Notes)

## Notes

Shipped in PR #445. Build recipe (the canonical one for milestone APKs — `flutter build apk`
hangs headless in this environment, so drive gradle directly):

```
cd app/android && ./gradlew :app:assembleDevRelease --no-daemon --console=plain \
  -Pdart-defines=<base64 API_BASE_URL=…>,<base64 CLIENT_HEADER=…>
```

First dev APK published manually to `gs://squadquest-v2-media/apk/squadquest-dev-b1.apk`;
automation of that publish is `v2-ci-cd-pipelines`.

## Follow-ups

- **Tracked as `v2-ci-cd-pipelines`:** automate the dev-APK build+upload on every develop push
  (this plan did it once, by hand).
- **Deferred:** iOS flavor schemes (xcconfig + Runner schemes) for `flutter build ipa --flavor`.
