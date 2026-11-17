-- Guest notes: an optional short note a guest leaves with their answer
-- ("bringing a friend", "running late"), through the guest-rsvp function.
-- See docs/guest-rsvp.md § Contract and § Guest notes.
--
-- Changes three objects that earlier files created, so this file must run
-- after them. squadquest-init.sh runs tables/*.sql in glob order, and
-- "instance_rsvp_notes" sorts after instance_guests, instance_guests_claim,
-- instance_members and instance_open_links in both the C and en_US
-- collations. On a running database, apply it by hand (docs/guest-rsvp.md
-- § Guest notes › Deploy).
--
-- Backward compatible: the guest-rsvp function from before this change keeps
-- working against it (it never reads or writes the note, and its 4-argument
-- RPC call resolves to the new function with the note arguments defaulted).

-- 1. The note itself. Hosts read it through their existing SELECT grant and
-- policy on instance_guests ("Hosts can read guests on their own events");
-- anon still has no privileges on the table. Empty notes are stored as NULL.
alter table public.instance_guests
add column note text null,
add constraint instance_guests_note_length check (
  note is null
  or char_length(note) between 1 and 200
);

-- 2. The open-link join takes the note. p_set_note says whether the caller
-- sent one: false leaves an existing note as it is (a status-only answer
-- never wipes it), true sets it to p_note, where NULL or blank clears it.
-- Otherwise unchanged from tables/instance_open_links.sql, including who may
-- call it: service_role only.
--
-- Replaced by an 8-argument version that also takes plus-ones:
-- tables/instance_rsvp_plus.sql.
DROP FUNCTION public.guest_rsvp_open_join (text, text, text, text);

CREATE FUNCTION public.guest_rsvp_open_join (
  p_token text,
  p_name text,
  p_phone text,
  p_status text,
  p_note text DEFAULT NULL,
  p_set_note boolean DEFAULT false
) RETURNS text AS $$
DECLARE
  link record;
  found_guest record;
  created boolean := false;
  v_note text := nullif(btrim(p_note), '');
BEGIN
  IF p_status IS NULL OR p_status NOT IN ('yes', 'maybe', 'no')
    OR p_name IS NULL OR char_length(btrim(p_name)) NOT BETWEEN 1 AND 80
    OR p_phone IS NULL OR p_phone !~ '^\+[1-9][0-9]{6,14}$'
    OR p_set_note IS NULL
    OR (p_set_note AND char_length(v_note) > 200) THEN
    RAISE EXCEPTION 'bad_request';
  END IF;

  IF NOT p_set_note THEN
    v_note := NULL;
  END IF;

  SELECT
    l.token, l.instance, l.closed_at, l.max_guests, l.guests_created,
    i.created_by AS host, i.status AS event_status
  INTO link
  FROM public.instance_open_links l
  JOIN public.instances i ON i.id = l.instance
  WHERE l.token = p_token
  FOR UPDATE OF l;

  IF NOT FOUND
    OR link.closed_at IS NOT NULL
    OR link.event_status <> 'live'
    OR link.guests_created >= link.max_guests THEN
    RAISE EXCEPTION 'not_found';
  END IF;

  -- the (host, phone) unique index makes this lookup-then-insert safe:
  -- a concurrent insert of the same phone fails and is retried as a reuse
  SELECT id, token, name INTO found_guest
  FROM public.guests
  WHERE host = link.host AND phone = p_phone
  FOR UPDATE;

  IF NOT FOUND THEN
    BEGIN
      INSERT INTO public.guests (host, name, phone)
      VALUES (link.host, btrim(p_name), p_phone)
      RETURNING id, token, name INTO found_guest;
      created := true;
    EXCEPTION WHEN unique_violation THEN
      SELECT id, token, name INTO found_guest
      FROM public.guests
      WHERE host = link.host AND phone = p_phone
      FOR UPDATE;
    END;
  ELSIF btrim(found_guest.name) = '' THEN
    UPDATE public.guests SET name = btrim(p_name) WHERE id = found_guest.id;
  END IF;

  INSERT INTO public.instance_guests (instance, guest, status, note)
  VALUES (link.instance, found_guest.id, p_status, v_note)
  ON CONFLICT (instance, guest) DO UPDATE
  SET
    status = excluded.status,
    note = CASE WHEN p_set_note THEN excluded.note ELSE public.instance_guests.note END;

  IF created THEN
    UPDATE public.instance_open_links
    SET guests_created = guests_created + 1
    WHERE token = link.token;
    RETURN found_guest.token;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.guest_rsvp_open_join (text, text, text, text, text, boolean)
FROM
  public,
  anon,
  authenticated;

GRANT
EXECUTE ON FUNCTION public.guest_rsvp_open_join (text, text, text, text, text, boolean) TO service_role;

-- 3. A claim copies the guest's note along with their answer, into
-- instance_members.note (free text, no constraint there), only when the
-- claim creates the member row: an existing member row for the event still
-- wins whole, note included. Otherwise unchanged from
-- tables/instance_guests_claim.sql. CREATE OR REPLACE keeps the owner,
-- SECURITY DEFINER and the grants (service_role only).
--
-- Replaced by a version that also folds plus-ones into the note:
-- tables/instance_rsvp_plus.sql.
CREATE OR REPLACE FUNCTION public.guest_claim_for_user (p_user uuid) RETURNS integer AS $$
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
    INSERT INTO public.instance_members (instance, member, status, created_by, note)
    SELECT ig.instance, p_user, ig.status::public.instance_member_status, g.host, ig.note
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
