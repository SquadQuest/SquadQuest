-- Checks for guest notes (tables/instance_rsvp_notes.sql): the column and
-- its limit, who can read it, the open-link join with and without a note,
-- and the claim copying it to a new member row.
--
-- Runs against a LOCAL database that has the SquadQuest schema loaded (see
-- docs/guest-rsvp.md § Testing). Everything happens inside one transaction
-- that is rolled back, so it leaves nothing behind. Any failed check raises
-- and stops the script (run psql with -v ON_ERROR_STOP=1).
--
-- Invented people and numbers only (555-01xx). Needs GoTrue's auth schema
-- for the claim part, like tests/guests_claim.sql.
--
--   a1 Host One, a2 Host Two                  hosts
--   b1 Sam  +15555550100  Host One's guest    notes on e1/e2, claimed by c1
--   c1 Sam  signed in by SMS code              -> claims at signup; in the
--                                                 second transaction, already
--                                                 a member of e2
begin;

insert into
  auth.users (id, aud, role, phone, phone_confirmed_at, email, raw_app_meta_data)
values
  ('00000000-0000-4000-8000-0000000000a1', 'authenticated', 'authenticated', '15555550101', now() - interval '1 hour', null, '{}'),
  ('00000000-0000-4000-8000-0000000000a2', 'authenticated', 'authenticated', '15555550102', now() - interval '1 hour', null, '{}'),
  ('00000000-0000-4000-8000-0000000000c1', 'authenticated', 'authenticated', '15555550100', now() - interval '1 hour', null, '{}');

insert into
  auth.sessions (id, user_id, created_at, updated_at)
values
  ('dddddddd-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000c1', now(), now());

insert into
  auth.mfa_amr_claims (id, session_id, authentication_method, created_at, updated_at)
values
  (gen_random_uuid (), 'dddddddd-0000-4000-8000-0000000000c1', 'otp', now() - interval '59 minutes', now() - interval '59 minutes');

insert into
  public.profiles (id, first_name, last_name, phone)
values
  ('00000000-0000-4000-8000-0000000000a1', 'Host', 'One', '15555550101'),
  ('00000000-0000-4000-8000-0000000000a2', 'Host', 'Two', '15555550102');

insert into
  public.instances (id, created_by, title, location_description, rally_point, status, visibility)
values
  ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000a1', 'One live', 'Somewhere', 'POINT(-75.16 39.95)', 'live', 'private'),
  ('00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-0000000000a1', 'One later', 'Somewhere', 'POINT(-75.16 39.95)', 'live', 'private');

insert into
  public.guests (id, host, name, phone)
values
  ('00000000-0000-4000-8000-0000000000b1', '00000000-0000-4000-8000-0000000000a1', 'Sam Example', '+15555550100');

insert into
  public.instance_guests (instance, guest, status)
values
  ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000b1', 'invited'),
  ('00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-0000000000b1', 'invited');

insert into
  public.instance_open_links (instance, created_by, token)
values
  ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000a1', repeat('c', 64));

-- ── the column: nullable, 1–200 characters ──
do $$
begin
  assert (select note from public.instance_guests where guest = '00000000-0000-4000-8000-0000000000b1'
          and instance = '00000000-0000-4000-8000-0000000000e1') is null, 'note defaults to null';
  update public.instance_guests set note = repeat('é', 200)
  where guest = '00000000-0000-4000-8000-0000000000b1' and instance = '00000000-0000-4000-8000-0000000000e1';
  begin
    update public.instance_guests set note = repeat('x', 201)
    where guest = '00000000-0000-4000-8000-0000000000b1' and instance = '00000000-0000-4000-8000-0000000000e1';
    raise exception 'FAIL: 201-character note stored';
  exception when check_violation then null;
  end;
  begin
    update public.instance_guests set note = ''
    where guest = '00000000-0000-4000-8000-0000000000b1' and instance = '00000000-0000-4000-8000-0000000000e1';
    raise exception 'FAIL: empty note stored';
  exception when check_violation then null;
  end;
end $$;

-- ── open-link join: set, keep when omitted, change, clear, refuse ──
do $$
declare
  link text := repeat('c', 64);
  sam constant uuid := '00000000-0000-4000-8000-0000000000b1';
  e1 constant uuid := '00000000-0000-4000-8000-0000000000e1';
  t text;
  msg text;
begin
  update public.instance_guests set note = null where guest = sam and instance = e1;

  -- a new guest with a note
  t := public.guest_rsvp_open_join(link, 'Pat Example', '+15555550199', 'yes', '  Bringing a friend  ', true);
  assert t ~ '^[0-9a-f]{64}$', 'new guest still gets a token';
  assert (select ig.note from public.instance_guests ig join public.guests g on g.id = ig.guest
          where g.token = t) = 'Bringing a friend', 'note stored, trimmed';

  -- a second post from the same phone, status only: note kept, answer changed
  assert public.guest_rsvp_open_join(link, 'Pat', '+15555550199', 'maybe') is null, 'reuse: no token';
  assert (select ig.status || '|' || ig.note from public.instance_guests ig join public.guests g on g.id = ig.guest
          where g.phone = '+15555550199') = 'maybe|Bringing a friend', 'omitted note keeps the stored one';
  assert public.guest_rsvp_open_join(link, 'Pat', '+15555550199', 'yes', 'ignored', false) is null, 'p_set_note false';
  assert (select ig.note from public.instance_guests ig join public.guests g on g.id = ig.guest
          where g.phone = '+15555550199') = 'Bringing a friend', 'p_set_note false ignores p_note';

  -- a second post from the same phone with a note: changed
  perform public.guest_rsvp_open_join(link, 'Pat', '+15555550199', 'yes', 'Running late', true);
  assert (select ig.note from public.instance_guests ig join public.guests g on g.id = ig.guest
          where g.phone = '+15555550199') = 'Running late', 'note changed';

  -- clear with null and with blank
  perform public.guest_rsvp_open_join(link, 'Pat', '+15555550199', 'yes', null, true);
  assert (select ig.note from public.instance_guests ig join public.guests g on g.id = ig.guest
          where g.phone = '+15555550199') is null, 'null clears';
  perform public.guest_rsvp_open_join(link, 'Pat', '+15555550199', 'yes', 'again', true);
  perform public.guest_rsvp_open_join(link, 'Pat', '+15555550199', 'no', '   ', true);
  assert (select ig.status || '|' || coalesce(ig.note, '<null>') from public.instance_guests ig join public.guests g on g.id = ig.guest
          where g.phone = '+15555550199') = 'no|<null>', 'blank clears';

  -- the host-added guest answers through the open link with a note
  perform public.guest_rsvp_open_join(link, 'Sam', '+15555550100', 'yes', 'Can bring chairs', true);
  assert (select status || '|' || note from public.instance_guests where guest = sam and instance = e1)
    = 'yes|Can bring chairs', 'host-added guest note set through the open link';

  -- too long: nothing written
  begin
    perform public.guest_rsvp_open_join(link, 'Pat', '+15555550199', 'maybe', repeat('x', 201), true);
    raise exception 'FAIL: 201-character note accepted';
  exception when raise_exception then
    get stacked diagnostics msg = message_text;
    assert msg = 'bad_request', 'too long is bad_request, got ' || msg;
  end;
  assert (select ig.status from public.instance_guests ig join public.guests g on g.id = ig.guest
          where g.phone = '+15555550199') = 'no', 'refused call wrote nothing';

  -- 200 characters is fine
  perform public.guest_rsvp_open_join(link, 'Pat', '+15555550199', 'maybe', repeat('é', 200), true);

  begin
    perform public.guest_rsvp_open_join(link, 'Pat', '+15555550199', 'maybe', 'x', null);
    raise exception 'FAIL: null p_set_note accepted';
  exception when raise_exception then
    get stacked diagnostics msg = message_text;
    assert msg = 'bad_request', 'null p_set_note is bad_request, got ' || msg;
  end;

  assert (select guests_created from public.instance_open_links) = 1, 'only the first join created a guest';
end $$;

-- ── who may call the join and read notes ──
do $$
begin
  assert has_function_privilege('service_role', 'public.guest_rsvp_open_join(text, text, text, text, text, boolean)', 'execute'),
    'service_role may join';
  assert not has_function_privilege('anon', 'public.guest_rsvp_open_join(text, text, text, text, text, boolean)', 'execute'),
    'anon may not join';
  assert not has_function_privilege('authenticated', 'public.guest_rsvp_open_join(text, text, text, text, text, boolean)', 'execute'),
    'authenticated may not join';
  assert to_regprocedure('public.guest_rsvp_open_join(text, text, text, text)') is null, 'no 4-argument overload left';
  assert not has_column_privilege('anon', 'public.instance_guests', 'note', 'select'), 'anon cannot read notes';
end $$;

set local role authenticated;

select
  set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}', true),
  set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-0000000000a1', true);

do $$
begin
  assert (select note from public.instance_guests where guest = '00000000-0000-4000-8000-0000000000b1'
          and instance = '00000000-0000-4000-8000-0000000000e1') = 'Can bring chairs', 'host reads their guest''s note';
end $$;

select
  set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a2","role":"authenticated"}', true),
  set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-0000000000a2', true);

do $$
begin
  assert (select count(*) from public.instance_guests) = 0, 'another host sees no guest rows or notes';
end $$;

-- the guest-to-be, before claiming, cannot read their own guest rows either
select
  set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000c1","role":"authenticated"}', true),
  set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-0000000000c1', true);

do $$
begin
  assert (select count(*) from public.instance_guests) = 0, 'a non-host sees no guest rows';
end $$;

reset role;

-- ── claim: the note moves to a new member row; an existing one wins ──
update public.instance_guests set status = 'maybe', note = 'Guest note on e2'
where guest = '00000000-0000-4000-8000-0000000000b1' and instance = '00000000-0000-4000-8000-0000000000e2';

-- Sam signs up: the profile insert runs the claim
insert into
  public.profiles (id, first_name, last_name, phone)
values
  ('00000000-0000-4000-8000-0000000000c1', 'Sam', 'Example', '15555550100');

-- the profile insert above ran the claim; check what it made
do $$
declare
  sam_user constant uuid := '00000000-0000-4000-8000-0000000000c1';
begin
  assert (select claimed_by from public.guests where id = '00000000-0000-4000-8000-0000000000b1') = sam_user, 'claimed';
  assert (select status::text || '|' || note from public.instance_members
          where member = sam_user and instance = '00000000-0000-4000-8000-0000000000e1') = 'yes|Can bring chairs',
    'claim copies the note to the new member row';
  assert (select status::text || '|' || note from public.instance_members
          where member = sam_user and instance = '00000000-0000-4000-8000-0000000000e2') = 'maybe|Guest note on e2',
    'claim copies each event''s own note';
  assert (select note from public.instance_guests where guest = '00000000-0000-4000-8000-0000000000b1'
          and instance = '00000000-0000-4000-8000-0000000000e1') = 'Can bring chairs', 'guest row kept as it was';
end $$;

rollback;

-- existing member row wins, note included (separate transaction: the
-- member row must exist before the claim)
begin;

insert into
  auth.users (id, aud, role, phone, phone_confirmed_at, email, raw_app_meta_data)
values
  ('00000000-0000-4000-8000-0000000000a1', 'authenticated', 'authenticated', '15555550101', now() - interval '1 hour', null, '{}'),
  ('00000000-0000-4000-8000-0000000000c1', 'authenticated', 'authenticated', '15555550100', now() - interval '1 hour', null, '{}');

insert into
  auth.sessions (id, user_id, created_at, updated_at)
values
  ('dddddddd-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000c1', now(), now());

insert into
  auth.mfa_amr_claims (id, session_id, authentication_method, created_at, updated_at)
values
  (gen_random_uuid (), 'dddddddd-0000-4000-8000-0000000000c1', 'otp', now() - interval '59 minutes', now() - interval '59 minutes');

-- c1 has a profile before the host adds their number (claimed later via guest_claim_mine)
insert into
  public.profiles (id, first_name, last_name, phone)
values
  ('00000000-0000-4000-8000-0000000000a1', 'Host', 'One', '15555550101'),
  ('00000000-0000-4000-8000-0000000000c1', 'Sam', 'Example', '15555550100');

insert into
  public.instances (id, created_by, title, location_description, rally_point, status, visibility)
values
  ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000a1', 'One live', 'Somewhere', 'POINT(-75.16 39.95)', 'live', 'private'),
  ('00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-0000000000a1', 'One later', 'Somewhere', 'POINT(-75.16 39.95)', 'live', 'private');

insert into
  public.instance_members (instance, member, status, created_by, note)
values
  ('00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-0000000000c1', 'yes', '00000000-0000-4000-8000-0000000000c1', 'Member note');

insert into
  public.guests (id, host, name, phone)
values
  ('00000000-0000-4000-8000-0000000000b1', '00000000-0000-4000-8000-0000000000a1', 'Sam Example', '+15555550100');

insert into
  public.instance_guests (instance, guest, status, note)
values
  ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000b1', 'no', null),
  ('00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-0000000000b1', 'maybe', 'Guest note on e2');

do $$
declare
  sam_user constant uuid := '00000000-0000-4000-8000-0000000000c1';
begin
  assert public.guest_claim_for_user(sam_user) = 1, 'one guest row claimed';
  assert (select status::text || '|' || note from public.instance_members
          where member = sam_user and instance = '00000000-0000-4000-8000-0000000000e2') = 'yes|Member note',
    'existing member row wins, note included';
  assert (select status::text || '|' || coalesce(note, '<null>') from public.instance_members
          where member = sam_user and instance = '00000000-0000-4000-8000-0000000000e1') = 'no|<null>',
    'no guest note: member note null';
end $$;

rollback;

select 'guests_note: all checks passed' as result;
