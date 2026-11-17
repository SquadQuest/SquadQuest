-- Guests who become members. When someone a host added as a guest signs up
-- and proves their phone number, each guest row with that number (from every
-- host) is "claimed": the guest's answers become real RSVPs in
-- instance_members, the guest row records who claimed it, and the host gets a
-- pending friend request to the new member. See docs/guest-rsvp.md
-- § Guests who become members.
--
-- Purely additive: two new columns on guests, one index, three functions and
-- one trigger on profiles. Nothing existing calls them.
--
-- "Proven" is decided from GoTrue's own tables, never from the client:
-- profiles.phone is written by the app and RLS checks only its id. See
-- guest_claim_verified_phone() below for the rule.
alter table public.guests
add column claimed_by uuid null,
add column claimed_at timestamp with time zone null,
add constraint guests_claimed_by_fkey foreign key (claimed_by) references profiles (id) on delete set null;

-- the claim looks guests up by phone across all hosts
create index guests_phone_unclaimed_idx on public.guests (phone)
where
  phone is not null
  and claimed_by is null;

-- The user's phone in E.164 when they have proven it with an SMS code, else
-- NULL. auth.users.phone is digits without '+', as GoTrue stores it.
--
-- phone_confirmed_at alone is not proof: with GOTRUE_SMS_AUTOCONFIRM on
-- (ENABLE_PHONE_AUTOCONFIRM in .env), GoTrue sets it on a password signup and
-- on a phone change with no SMS at all. So the phone counts only when, in
-- addition, one of the user's sessions was signed in by a one-time code
-- (auth.mfa_amr_claims.authentication_method = 'otp') at or after the moment
-- the current phone was confirmed: a code that can only have gone to that
-- phone. Email codes and magic links are also 'otp', so an account with an
-- email is never treated as phone-proven (the app signs in by phone only).
CREATE FUNCTION public.guest_claim_verified_phone (p_user uuid) RETURNS text AS $$
  SELECT '+' || ltrim(u.phone, '+')
  FROM auth.users u
  WHERE u.id = p_user
    AND u.phone IS NOT NULL
    AND u.phone_confirmed_at IS NOT NULL
    AND coalesce(u.email, '') = ''
    AND '+' || ltrim(u.phone, '+') ~ '^\+[1-9][0-9]{6,14}$'
    AND EXISTS (
      SELECT 1
      FROM auth.sessions s
      JOIN auth.mfa_amr_claims c ON c.session_id = s.id
      WHERE s.user_id = u.id
        AND c.authentication_method = 'otp'
        AND c.updated_at >= u.phone_confirmed_at
    )
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

-- Claim every unclaimed guest row whose phone is p_user's verified phone.
-- Returns how many guest rows were claimed (0 when the phone is not proven,
-- there is no profile, or there is nothing to claim). Idempotent: claimed
-- rows are skipped, member rows are inserted with ON CONFLICT DO NOTHING.
--
-- Per claimed guest:
--   1. each answer on the host's own non-draft events becomes an
--      instance_members row (same status: invited/yes/maybe/no all exist in
--      instance_member_status), created_by the host, as the v1 invite
--      function does. An existing member row for that event always wins.
--   2. the host gets a pending friend request to the member, unless any
--      friends row already exists between them in either direction, or the
--      host is in the user's app_metadata.invite_friends: on-profile-insert
--      creates those requests itself, and a row inserted here first would
--      make its batch upsert fail.
--   3. the guest row gets claimed_by / claimed_at.
--
-- Replaced by a version that also copies the guest's note:
-- tables/instance_rsvp_notes.sql.
CREATE FUNCTION public.guest_claim_for_user (p_user uuid) RETURNS integer AS $$
DECLARE
  v_phone text;
  v_invite_friends jsonb;
  g record;
  claimed integer := 0;
BEGIN
  IF p_user IS NULL THEN
    RETURN 0;
  END IF;

  v_phone := public.guest_claim_verified_phone(p_user);
  IF v_phone IS NULL THEN
    RETURN 0;
  END IF;

  -- instance_members.member must be a profile
  PERFORM 1 FROM public.profiles WHERE id = p_user;
  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  SELECT coalesce(raw_app_meta_data -> 'invite_friends', '[]'::jsonb)
  INTO v_invite_friends
  FROM auth.users
  WHERE id = p_user;

  FOR g IN
    SELECT id, host
    FROM public.guests
    WHERE phone = v_phone
      AND claimed_by IS NULL
    ORDER BY created_at, id
    FOR UPDATE
  LOOP
    INSERT INTO public.instance_members (instance, member, status, created_by)
    SELECT ig.instance, p_user, ig.status::public.instance_member_status, g.host
    FROM public.instance_guests ig
    JOIN public.instances i ON i.id = ig.instance
    WHERE ig.guest = g.id
      AND i.created_by = g.host
      AND i.status <> 'draft'
    ON CONFLICT (instance, member) DO NOTHING;

    IF g.host <> p_user
      AND NOT (jsonb_typeof(v_invite_friends) = 'array' AND v_invite_friends ? g.host::text)
      AND NOT EXISTS (
        SELECT 1 FROM public.friends f
        WHERE (f.requester = g.host AND f.requestee = p_user)
           OR (f.requester = p_user AND f.requestee = g.host)
      ) THEN
      INSERT INTO public.friends (requester, requestee, status)
      VALUES (g.host, p_user, 'requested')
      ON CONFLICT (requester, requestee) DO NOTHING;
    END IF;

    UPDATE public.guests
    SET claimed_by = p_user, claimed_at = now()
    WHERE id = g.id;

    claimed := claimed + 1;
  END LOOP;

  RETURN claimed;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- The signed-in user claims for themself, e.g. after a host adds their
-- number as a guest when they already have a profile. Only ever auth.uid().
CREATE FUNCTION public.guest_claim_mine () RETURNS integer AS $$
  SELECT public.guest_claim_for_user(auth.uid())
$$ LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp;

-- Runs the claim when a profile is created (the app creates it right after
-- the SMS code is verified). A failure is logged and swallowed: the claim
-- must never block signup. The exception block rolls back a partial claim.
CREATE FUNCTION public.guest_claim_on_profile_insert () RETURNS trigger AS $$
BEGIN
  BEGIN
    PERFORM public.guest_claim_for_user(NEW.id);
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'guest_claim_for_user(%) failed: % (%)', NEW.id, SQLERRM, SQLSTATE;
  END;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

CREATE TRIGGER guest_claim_on_profile_insert
AFTER INSERT ON public.profiles FOR EACH ROW
EXECUTE FUNCTION public.guest_claim_on_profile_insert ();

REVOKE ALL ON FUNCTION public.guest_claim_verified_phone (uuid)
FROM
  public,
  anon,
  authenticated;

REVOKE ALL ON FUNCTION public.guest_claim_for_user (uuid)
FROM
  public,
  anon,
  authenticated;

REVOKE ALL ON FUNCTION public.guest_claim_on_profile_insert ()
FROM
  public,
  anon,
  authenticated;

REVOKE ALL ON FUNCTION public.guest_claim_mine ()
FROM
  public,
  anon;

GRANT
EXECUTE ON FUNCTION public.guest_claim_for_user (uuid) TO service_role;

GRANT
EXECUTE ON FUNCTION public.guest_claim_mine () TO authenticated;
