---
status: in-progress
depends: [specops-foundation]
specs:
  - specs/architecture.md
issues: []
pr:
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

- [ ] `cd app && flutter analyze && flutter test` clean on the fresh app.
- [ ] `cd server && bun install && bun run dev` boots; `GET /v1/health` → `{status:"ok"}`;
      `bun run type-check` clean.
- [ ] `supabase/` and the root Flutter app are gone; `app/` + `server/` present.
- [ ] vendored `specops` CLI still runs; this plan listed.
- [ ] kept workflows YAML-valid; `pr-test` exercised on first push.
- [ ] `v2-publish` builds `app/` web and serves `v2.squadquest.app` (placeholder until
      screens are re-ported — expected).

## Risks / unknowns

- `v2.squadquest.app` serves the fresh placeholder app until screens are re-ported (accepted).
- Native Firebase/signing/iOS extension dropped; bundle id preserved via `--org`, must be
  re-added before any release (Follow-up).
- FVM→asdf in CI must install Flutter from `.tool-versions` — validate on first run.

## Notes

(closeout)

## Follow-ups

(closeout)
