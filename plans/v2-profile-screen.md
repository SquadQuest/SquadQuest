---
status: planned
depends: [v2-storage-media]
specs:
  - specs/screens/profile.md
  - specs/api/profile.md
  - specs/api/uploads.md
issues: []
pr:
---

# Plan: v2 profile screen (view/edit name + photo, sign out)

> Surfaced from real on-device use: a user who skipped the photo at onboarding has **no way to
> add it later** — photo/name edit lives only in the welcome step, and the router's onboarding
> gate (keyed on `first_name`) can never route back to `/welcome` once a name is set. Every
> backend + client primitive already exists (`PATCH /v1/me` with `photo`,
> `ProfileRepository.updateProfile`, `authController.updateProfile`, the `PhotoPicker` with
> `currentUrl`); the entire gap is one screen + an entry point.

## Scope

Build the `/profile` screen per [`specs/screens/profile.md`](../specs/screens/profile.md): view +
edit own name and photo, phone shown read-only, and sign out (relocated here from the timeline
app bar).

**In:**

- `ProfileScreen` (`app/lib/screens/profile/profile_screen.dart`) — avatar (`PhotoPicker`,
  kind `profile`, seeded with `currentUrl` = current photo), first/last name fields, read-only
  phone, Save (enabled only on change + non-empty first name), Sign out.
- Route `/profile` in `router.dart`.
- **Entry point:** make the timeline app-bar avatar tappable → `context.push('/profile')`,
  replacing the bare logout `IconButton` (sign-out moves into the profile screen).
- Save calls `authController.updateProfile(...)` with only changed fields; photo-only save works.
- Widget tests + `flutter analyze`.

**Out:** other-user profile screens; notification-preference editing; clearing a photo
(empty-string `photo` — API supports it, defer the UI); any styling pass.

## Implements

`specs/screens/profile.md` (new). Reuses the existing `api/profile.md` `PATCH /v1/me` (photo) and
`api/uploads.md` contracts — no API change. Pure client wiring + one new screen.

## Approach (refine at pickup)

- Reuse `PhotoPicker(kind: 'profile', currentUrl: profile.photo, onUploaded: ...)` — it already
  pre-populates the avatar and reports the stored public URL.
- Hold pending photo URL + name edits in screen state; Save sends only what changed (mirror
  `welcome_screen.dart`'s `_save`). `updateProfile` already accepts optional `firstName` so a
  photo-only / last-name-only patch is fine.
- Read current profile from `authControllerProvider`'s `SignedIn(profile)`.
- Timeline app bar: swap the `logoutButton` IconButton for a tappable `CircleAvatar` (current
  photo or initials) routing to `/profile`; move sign-out into the profile screen.

## Validation

- [ ] `/profile` renders current name + photo + read-only phone; reachable from the timeline
      avatar.
- [ ] Changing the photo and saving persists (`PATCH /v1/me`), avatar updates app-wide; a
      photo-only save (name untouched) works; Save guard keeps first name non-empty.
- [ ] Sign out works from the profile screen; the timeline no longer carries a standalone logout
      button.
- [ ] `flutter analyze` + widget tests clean; CI `app` job.
- [ ] (on-device) build `squadquest-dev-b{N}.apk`, set a photo from the phone, confirm it sticks.

## Risks / unknowns

- Avatar-as-button in the app bar: keep a sensible fallback (initials/glyph) when `photo` is null
  so the entry point is always visible.
- `Profile` model is currently a read-only DTO (no `copyWith`); not needed — `updateProfile`
  returns the fresh profile from the server and swaps auth state.

## Notes

(closeout)

## Follow-ups

(closeout)
