---
status: done
depends: [specops-foundation]
specs:
  - specs/architecture.md
issues: []
pr: 406
---

# Plan: v2 repo reset — purge v1, fresh Flutter app in `app/`, scaffold `server/`

## Scope

Clean `develop` into the real v2 trunk: purge the Supabase backend + the root v1 Flutter app
(both archived on the protected `v1` branch), install latest stable Flutter, initialize a
**fresh** Flutter client under `app/`, scaffold the `server/` backend (Fastify/Bun, boot +
`/v1` skeleton only), and rework CI/tooling to match.

Out: re-porting v2 screens from `v1`; native Firebase/push/signing/iOS notification
extension; DB/auth/realtime/migration (`v2-backend-and-migration`); README rewrite; v2
release workflows.

## Implements

`specs/architecture.md` (the new `app/` + `server/` layout and the single-client model).

## Approach

1. Spec-first: update `architecture.md` layout + run commands; rewrite `.claude/CLAUDE.md`
   to the `app/`+`server/` shape.
2. Purge `supabase/` + the root Flutter app + root flutter/env files.
3. Toolchain: `asdf set flutter latest`, `asdf set bun latest`, drop `deno` from
   `.tool-versions` (keep opentofu, ruby).
4. `flutter create --org app --project-name squadquest --platforms android,ios,macos,web app`
   (bundle `app.squadquest` preserved; windows/linux dropped).
5. `server/` Fastify/Bun scaffold per the backend-fastify skill: boot + `GET /v1/health`,
   dir skeleton (`domain/ routes/v1/ contracts/ realtime/ migrations/`), `.env.example`.
6. CI: delete the 6 v1/storybook workflows; rewrite `pr-test` (app analyze+test, server
   type-check via asdf); rewire `v2-publish` to build `app/` web. Replace FVM with the asdf
   install action (versions confirmed via `gh-axi`). Update `.vscode/launch.json`.

## Validation

- [x] `cd app && flutter analyze && flutter test` clean on the fresh app.
- [x] `cd server && bun install && bun run dev` boots; `GET /v1/health` → `{status:"ok"}`;
      `bun run type-check` clean.
- [x] `supabase/` and the root Flutter app are gone; `app/` + `server/` present.
- [x] vendored `specops` CLI still runs; this plan listed.
- [x] kept workflows YAML-valid; `pr-test` to be exercised on first push (PR #406).
- [ ] `v2-publish` builds `app/` web and serves `v2.squadquest.app` — verified on merge to
      develop (placeholder app until screens are re-ported — expected).

## Risks / unknowns

- `v2.squadquest.app` serves the fresh placeholder app until screens are re-ported (accepted).
- Native Firebase/signing/iOS extension dropped; bundle id preserved via `--org`, must be
  re-added before any release (Follow-up).
- FVM→asdf in CI must install Flutter from `.tool-versions` — validate on first run.

## Notes

Shipped as PR #406 (5 logical commits: spec retarget, purge, app init, server scaffold, CI).
Flutter resolved to `3.44.1-stable` (newest stable at the time, not the 3.41.x seen during
planning). Backend uses Bun-native ESM (`.ts` import specifiers, `types: ["bun"]`), `/v1`
prefix, `GET /v1/health` → `{status:"ok"}` (verified live + 404 on unknown + graceful
shutdown). CI deviation from the plan: the blanket asdf install action is unusable here
because it would try to install every `.tool-versions` tool including the `ruby 4.0.0` pin
(no such release → would fail); so Bun reads `.tool-versions` via `setup-bun`, while the
Flutter version is mirrored in the workflows via `subosito/flutter-action` with a sync note.
FVM is fully dropped; `.tool-versions` remains the canonical local source.

## Follow-ups

- **Deferred to plan:** `v2-backend-and-migration` — DB/auth/realtime/migrations + the bulk
  pre-migration & claim-on-login.
- **Deferred (not yet filed):** re-port v2 screens from the `v1` branch onto `app/`; re-add
  native Firebase/FCM + signing + iOS notification extension before any store release;
  rewrite the root `README.md` (still v1); reintroduce v2 app-store release workflows.
- **Watch on merge:** confirm `v2-publish` succeeds and `v2.squadquest.app` serves the fresh
  app (expected placeholder).
