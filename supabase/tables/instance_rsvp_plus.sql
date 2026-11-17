-- Plus-ones: how many extra people a guest is bringing (0-9, not counting
-- the guest), set through the guest-rsvp function. See docs/guest-rsvp.md
-- § Contract and § Plus-ones.
--
-- Changes objects that earlier files created, so this file must run after
-- them. squadquest-init.sh runs tables/*.sql in glob order, and
-- "instance_rsvp_plus" sorts after guests, instance_guests,
-- instance_guests_claim, instance_members, instance_open_links and
-- instance_rsvp_notes in both the C and en_US collations. On a running
-- database, apply it by hand (docs/guest-rsvp.md § Plus-ones › Deploy).
--
-- Backward compatible: the guest-rsvp function from before this change keeps
-- working against it (it never reads or writes plus or open_link, and its
-- 6-argument RPC call resolves to the new join with the plus arguments
-- defaulted, which leave a stored plus as it is).

-- 1. The plus-ones. Stored whatever the answer; readers count them only
-- when the answer is yes or maybe. Hosts read (and may write) the column
-- through their existing grants and policies on instance_guests.
alter table public.instance_guests
add column plus smallint not null default 0,
add constraint instance_guests_plus_range check (plus between 0 and 9);

-- 2. Which open link created a guest. Set only by guest_rsvp_open_join()
-- when it creates the guest; hosts can read it but never write it (their
-- insert and update grants on guests are per column). NULL for guests a host
-- added, and for guests created through a link before this file was applied.
alter table public.guests
add column open_link text null,
add constraint guests_open_link_fkey foreign key (open_link) references instance_open_links (token) on delete set null;

create index guests_open_link_idx on public.guests (open_link)
where
  open_link is not null;

-- 3. The plus-ones a link holds: those of the guests it created, on its own
-- event, while their answer is yes or maybe. The link's cap counts these on
-- top of guests_created (one per guest it created, as before):
--   guests_created + guest_open_link_plus(token) <= max_guests
CREATE FUNCTION public.guest_open_link_plus (p_token text) RETURNS integer AS $$
  SELECT coalesce(sum(ig.plus), 0)::integer
  FROM public.instance_open_links l
  JOIN public.guests g ON g.open_link = l.token
  JOIN public.instance_guests ig ON ig.guest = g.id AND ig.instance = l.instance
  WHERE l.token = p_token
    AND ig.status IN ('yes', 'maybe');
$$ LANGUAGE sql STABLE SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.guest_open_link_plus (text)
FROM
  public,
  anon,
  authenticated;

GRANT
EXECUTE ON FUNCTION public.guest_open_link_plus (text) TO service_role;

-- 4. The open-link join takes plus-ones. p_set_plus says whether the caller
-- sent `plus`: false leaves a stored value as it is, true sets it to p_plus
-- (NULL meaning 0). A link that is full (guests_created plus the plus-ones
-- it holds reaches max_guests) refuses everyone, as before; a join that
-- would take it over max_guests is refused the same way ('not_found') and
-- writes nothing. Otherwise unchanged from tables/instance_rsvp_notes.sql,
-- including who may call it: service_role only.
DROP FUNCTION public.guest_rsvp_open_join (text, text, text, text, text, boolean);

CREATE FUNCTION public.guest_rsvp_open_join (
  p_token text,
  p_name text,
  p_phone text,
  p_status text,
  p_note text DEFAULT NULL,
  p_set_note boolean DEFAULT false,
  p_plus integer DEFAULT NULL,
  p_set_plus boolean DEFAULT false
) RETURNS text AS $$
DECLARE
  link record;
  found_guest record;
  old_row record;
  created boolean := false;
  v_note text := nullif(btrim(p_note), '');
  v_plus integer;
  v_used integer;
  v_delta integer := 0;
BEGIN
  IF p_status IS NULL OR p_status NOT IN ('yes', 'maybe', 'no')
    OR p_name IS NULL OR char_length(btrim(p_name)) NOT BETWEEN 1 AND 80
    OR p_phone IS NULL OR p_phone !~ '^\+[1-9][0-9]{6,14}$'
    OR p_set_note IS NULL
    OR (p_set_note AND char_length(v_note) > 200)
    OR p_set_plus IS NULL
    OR (p_set_plus AND coalesce(p_plus, 0) NOT BETWEEN 0 AND 9) THEN
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
    OR link.event_status <> 'live' THEN
    RAISE EXCEPTION 'not_found';
  END IF;

  -- the link row lock above serialises every write that changes this count
  v_used := link.guests_created + public.guest_open_link_plus(link.token);
  IF v_used >= link.max_guests THEN
    RAISE EXCEPTION 'not_found';
  END IF;

  -- the (host, phone) unique index makes this lookup-then-insert safe:
  -- a concurrent insert of the same phone fails and is retried as a reuse
  SELECT id, token, name, open_link INTO found_guest
  FROM public.guests
  WHERE host = link.host AND phone = p_phone
  FOR UPDATE;

  IF NOT FOUND THEN
    BEGIN
      INSERT INTO public.guests (host, name, phone, open_link)
      VALUES (link.host, btrim(p_name), p_phone, link.token)
      RETURNING id, token, name, open_link INTO found_guest;
      created := true;
    EXCEPTION WHEN unique_violation THEN
      SELECT id, token, name, open_link INTO found_guest
      FROM public.guests
      WHERE host = link.host AND phone = p_phone
      FOR UPDATE;
    END;
  ELSIF btrim(found_guest.name) = '' THEN
    UPDATE public.guests SET name = btrim(p_name) WHERE id = found_guest.id;
  END IF;

  SELECT status, plus INTO old_row
  FROM public.instance_guests
  WHERE instance = link.instance AND guest = found_guest.id
  FOR UPDATE;

  v_plus := CASE
    WHEN p_set_plus THEN coalesce(p_plus, 0)
    WHEN old_row.plus IS NOT NULL THEN old_row.plus
    ELSE 0
  END;

  -- only the plus-ones of guests this link created count against its cap
  IF found_guest.open_link IS NOT DISTINCT FROM link.token THEN
    v_delta := (CASE WHEN p_status IN ('yes', 'maybe') THEN v_plus ELSE 0 END)
      - (CASE WHEN old_row.status IN ('yes', 'maybe') THEN old_row.plus ELSE 0 END);
  END IF;

  -- raising here rolls back a guest created above as well
  IF v_used + (CASE WHEN created THEN 1 ELSE 0 END) + v_delta > link.max_guests THEN
    RAISE EXCEPTION 'not_found';
  END IF;

  INSERT INTO public.instance_guests (instance, guest, status, note, plus)
  VALUES (link.instance, found_guest.id, p_status, v_note, v_plus)
  ON CONFLICT (instance, guest) DO UPDATE
  SET
    status = excluded.status,
    note = CASE WHEN p_set_note THEN excluded.note ELSE public.instance_guests.note END,
    plus = excluded.plus;

  IF created THEN
    UPDATE public.instance_open_links
    SET guests_created = guests_created + 1
    WHERE token = link.token;
    RETURN found_guest.token;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.guest_rsvp_open_join (text, text, text, text, text, boolean, integer, boolean)
FROM
  public,
  anon,
  authenticated;

GRANT
EXECUTE ON FUNCTION public.guest_rsvp_open_join (text, text, text, text, text, boolean, integer, boolean) TO service_role;

-- 5. A guest's answer through their own link (guest-rsvp POST {t,...}),
-- which the function used to write with a plain UPDATE. It is a function now
-- so that a guest an open link created cannot take that link over its cap by
-- raising their plus-ones afterwards: when the answer adds to the plus-ones
-- the link holds and the total would pass max_guests, nothing is written and
-- it returns false (the function answers 404, as for a full link). Lowering
-- is always allowed. The cap applies whether or not the link is still open.
-- p_set_note / p_set_plus false leave the stored value as it is. Returns
-- false when the guest is not on the event. service_role only.
CREATE FUNCTION public.guest_rsvp_answer (
  p_guest uuid,
  p_instance uuid,
  p_status text,
  p_note text DEFAULT NULL,
  p_set_note boolean DEFAULT false,
  p_plus integer DEFAULT NULL,
  p_set_plus boolean DEFAULT false
) RETURNS boolean AS $$
DECLARE
  v_open_link text;
  v_link text;
  v_max integer;
  v_created integer;
  old_row record;
  v_note text := nullif(btrim(p_note), '');
  v_plus integer;
  v_delta integer;
BEGIN
  IF p_status IS NULL OR p_status NOT IN ('yes', 'maybe', 'no')
    OR p_set_note IS NULL
    OR (p_set_note AND char_length(v_note) > 200)
    OR p_set_plus IS NULL
    OR (p_set_plus AND coalesce(p_plus, 0) NOT BETWEEN 0 AND 9) THEN
    RAISE EXCEPTION 'bad_request';
  END IF;

  SELECT open_link INTO v_open_link FROM public.guests WHERE id = p_guest;

  -- lock the link before the answer row, the same order as the join
  IF v_open_link IS NOT NULL THEN
    SELECT l.token, l.max_guests, l.guests_created INTO v_link, v_max, v_created
    FROM public.instance_open_links l
    WHERE l.token = v_open_link AND l.instance = p_instance
    FOR UPDATE;
  END IF;

  SELECT status, plus INTO old_row
  FROM public.instance_guests
  WHERE guest = p_guest AND instance = p_instance
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  v_plus := CASE WHEN p_set_plus THEN coalesce(p_plus, 0) ELSE old_row.plus END;

  IF v_link IS NOT NULL THEN
    v_delta := (CASE WHEN p_status IN ('yes', 'maybe') THEN v_plus ELSE 0 END)
      - (CASE WHEN old_row.status IN ('yes', 'maybe') THEN old_row.plus ELSE 0 END);
    IF v_delta > 0
      AND v_created + public.guest_open_link_plus(v_link) + v_delta > v_max THEN
      RETURN false;
    END IF;
  END IF;

  UPDATE public.instance_guests
  SET
    status = p_status,
    note = CASE WHEN p_set_note THEN v_note ELSE note END,
    plus = v_plus
  WHERE guest = p_guest AND instance = p_instance;

  RETURN true;
END;
$$ LANGUAGE plpgsql SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.guest_rsvp_answer (uuid, uuid, text, text, boolean, integer, boolean)
FROM
  public,
  anon,
  authenticated;

GRANT
EXECUTE ON FUNCTION public.guest_rsvp_answer (uuid, uuid, text, text, boolean, integer, boolean) TO service_role;

-- 6. A claim folds the plus-ones into the note it copies, because
-- instance_members has no plus-ones field: when the claim creates the member
-- row and the guest answered yes or maybe with plus > 0, the member note is
-- the guest's note followed by " (+N)", or "+N" when there is no note
-- (instance_members.note has no length limit; a guest note is at most 200
-- characters, so the result is at most 205). Plus-ones on an invited or no
-- answer are not copied: in the app they would read as people coming. An
-- existing member row still wins whole. Otherwise unchanged from
-- tables/instance_rsvp_notes.sql. CREATE OR REPLACE keeps the owner,
-- SECURITY DEFINER and the grants (service_role only).
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
    SELECT
      ig.instance, p_user, ig.status::public.instance_member_status, g.host,
      CASE
        WHEN ig.plus > 0 AND ig.status IN ('yes', 'maybe') THEN
          CASE WHEN ig.note IS NULL THEN '+' || ig.plus
               ELSE ig.note || ' (+' || ig.plus || ')' END
        ELSE ig.note
      END
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
