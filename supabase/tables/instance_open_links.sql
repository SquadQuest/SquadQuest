-- Open-call links: one link per event that anyone can use to answer without
-- an account and without a per-guest link, e.g. from a QR code on a printed
-- flyer. Answering through one, by phone, creates (or reuses) a `guests` row
-- for the event's host. See docs/guest-rsvp.md.
create table
  public.instance_open_links (
    -- same generator and format as guests.token (64 hex chars, 244 bits)
    token text not null default replace(
      gen_random_uuid ()::text || gen_random_uuid ()::text,
      '-',
      ''
    ),
    instance uuid not null,
    created_by uuid not null default auth.uid (),
    created_at timestamp with time zone not null default now(),
    closed_at timestamp with time zone null,
    -- abuse limit: how many guests one link may create, enforced by
    -- guest_rsvp_open_join() under a row lock
    max_guests integer not null default 300,
    guests_created integer not null default 0,
    constraint instance_open_links_pkey primary key (token),
    constraint instance_open_links_instance_fkey foreign key (instance) references instances (id) on delete cascade,
    constraint instance_open_links_created_by_fkey foreign key (created_by) references profiles (id) on delete cascade,
    constraint instance_open_links_max_guests_check check (max_guests between 0 and 10000)
  );

-- at most one open link per event at a time; closed links stay closed
create unique index instance_open_links_one_open_key on public.instance_open_links (instance)
where
  closed_at is null;

alter table public.instance_open_links enable row level security;

revoke all on public.instance_open_links
from
  anon,
  authenticated;

grant
select
,
delete on public.instance_open_links to authenticated;

grant insert (instance),
update (closed_at) on public.instance_open_links to authenticated;

-- Answer an event through its open link, by phone, atomically: lock the
-- link, check it is open, the event is live and the cap is not reached,
-- then find the host's guest with that phone or create one, attach them to
-- the event if needed and set the answer.
--
-- Returns the guest's token ONLY when this call created the guest, and NULL
-- when an existing guest was reused: handing an existing guest's token to
-- whoever typed their phone number would let anyone take over that person's
-- answers. A reused guest's name is kept (it is only filled in if empty).
-- The cap counts guests created through the link.
--
-- Errors are raised with fixed messages the guest-rsvp function maps to
-- responses: 'not_found' (unknown, closed, full, or event not live) and
-- 'bad_request'. Only the service role may call it.
CREATE FUNCTION public.guest_rsvp_open_join (
  p_token text,
  p_name text,
  p_phone text,
  p_status text
) RETURNS text AS $$
DECLARE
  link record;
  found_guest record;
  created boolean := false;
BEGIN
  IF p_status IS NULL OR p_status NOT IN ('yes', 'maybe', 'no')
    OR p_name IS NULL OR char_length(btrim(p_name)) NOT BETWEEN 1 AND 80
    OR p_phone IS NULL OR p_phone !~ '^\+[1-9][0-9]{6,14}$' THEN
    RAISE EXCEPTION 'bad_request';
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

  INSERT INTO public.instance_guests (instance, guest, status)
  VALUES (link.instance, found_guest.id, p_status)
  ON CONFLICT (instance, guest) DO UPDATE SET status = excluded.status;

  IF created THEN
    UPDATE public.instance_open_links
    SET guests_created = guests_created + 1
    WHERE token = link.token;
    RETURN found_guest.token;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.guest_rsvp_open_join (text, text, text, text)
FROM
  public,
  anon,
  authenticated;

GRANT
EXECUTE ON FUNCTION public.guest_rsvp_open_join (text, text, text, text) TO service_role;
