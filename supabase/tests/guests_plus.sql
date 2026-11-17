-- Checks for plus-ones (tables/instance_rsvp_plus.sql): the column and its
-- range, the open-link join and the guest's own answer setting, keeping and
-- clearing it, the open link's cap counting plus-ones, who may call what,
-- and the claim folding plus-ones into the member note.
--
-- Runs against a LOCAL database that has the SquadQuest schema loaded (see
-- docs/guest-rsvp.md § Testing). Everything happens inside one transaction
-- that is rolled back, so it leaves nothing behind. Any failed check raises
-- and stops the script (run psql with -v ON_ERROR_STOP=1).
--
-- Invented people and numbers only (555-01xx). Needs GoTrue's auth schema
-- for the claim part, like tests/guests_claim.sql.
--
--   a1 Host One                               host
--   b1 Sam  +15555550100  Host One's guest    added by the host, on e1/e2/e3
--   c1 Sam  signed in by SMS code              -> claims at signup
--   open link c…c on e1, max_guests 6
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

insert into
  public.profiles (id, first_name, last_name, phone)
values
  ('00000000-0000-4000-8000-0000000000a1', 'Host', 'One', '15555550101');

insert into
  public.instances (id, created_by, title, location_description, rally_point, status, visibility)
values
  ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000a1', 'One live', 'Somewhere', 'POINT(-75.16 39.95)', 'live', 'private'),
  ('00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-0000000000a1', 'One later', 'Somewhere', 'POINT(-75.16 39.95)', 'live', 'private'),
  ('00000000-0000-4000-8000-0000000000e3', '00000000-0000-4000-8000-0000000000a1', 'One more', 'Somewhere', 'POINT(-75.16 39.95)', 'live', 'private');

insert into
  public.guests (id, host, name, phone)
values
  ('00000000-0000-4000-8000-0000000000b1', '00000000-0000-4000-8000-0000000000a1', 'Sam Example', '+15555550100');

insert into
  public.instance_guests (instance, guest, status)
values
  ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000b1', 'invited'),
  ('00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-0000000000b1', 'invited'),
  ('00000000-0000-4000-8000-0000000000e3', '00000000-0000-4000-8000-0000000000b1', 'invited');

insert into
  public.instance_open_links (instance, created_by, token, max_guests)
values
  ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000a1', repeat('c', 64), 6);

-- ── the column: 0 by default, 0–9 ──
do $$
declare
  sam constant uuid := '00000000-0000-4000-8000-0000000000b1';
  e1 constant uuid := '00000000-0000-4000-8000-0000000000e1';
begin
  assert (select plus from public.instance_guests where guest = sam and instance = e1) = 0, 'plus defaults to 0';
  update public.instance_guests set plus = 9 where guest = sam and instance = e1;
  begin
    update public.instance_guests set plus = 10 where guest = sam and instance = e1;
    raise exception 'FAIL: plus 10 stored';
  exception when check_violation then null;
  end;
  begin
    update public.instance_guests set plus = -1 where guest = sam and instance = e1;
    raise exception 'FAIL: plus -1 stored';
  exception when check_violation then null;
  end;
  begin
    update public.instance_guests set plus = null where guest = sam and instance = e1;
    raise exception 'FAIL: null plus stored';
  exception when not_null_violation then null;
  end;
  update public.instance_guests set plus = 0 where guest = sam and instance = e1;
end $$;

-- ── open-link join: set, keep when omitted, zero, null, refuse ──
do $$
declare
  link constant text := repeat('c', 64);
  sam constant uuid := '00000000-0000-4000-8000-0000000000b1';
  e1 constant uuid := '00000000-0000-4000-8000-0000000000e1';
  t text;
  msg text;
begin
  -- a new guest bringing two: created by the link, holds 2 plus-ones
  t := public.guest_rsvp_open_join(link, 'Pat Example', '+15555550199', 'yes', null, false, 2, true);
  assert t ~ '^[0-9a-f]{64}$', 'new guest gets a token';
  assert (select g.open_link from public.guests g where g.token = t) = link, 'guest remembers the link that created it';
  assert (select ig.plus from public.instance_guests ig join public.guests g on g.id = ig.guest where g.token = t) = 2,
    'plus stored';
  assert public.guest_open_link_plus(link) = 2, 'the link holds 2 plus-ones';

  -- status only (old 6-argument call shape): plus kept, also on a no
  assert public.guest_rsvp_open_join(link, 'Pat', '+15555550199', 'no', null, false) is null, 'reuse: no token';
  assert (select ig.status || '|' || ig.plus from public.instance_guests ig join public.guests g on g.id = ig.guest
          where g.phone = '+15555550199') = 'no|2', 'omitted plus kept when the answer changes to no';
  assert public.guest_open_link_plus(link) = 0, 'a no holds no plus-ones';
  perform public.guest_rsvp_open_join(link, 'Pat', '+15555550199', 'maybe');
  assert public.guest_open_link_plus(link) = 2, 'maybe counts the kept plus-ones again';
  perform public.guest_rsvp_open_join(link, 'Pat', '+15555550199', 'yes', null, false, 7, false);
  assert (select ig.plus from public.instance_guests ig join public.guests g on g.id = ig.guest
          where g.phone = '+15555550199') = 2, 'p_set_plus false ignores p_plus';

  -- zero and null both set 0
  perform public.guest_rsvp_open_join(link, 'Pat', '+15555550199', 'yes', null, false, 0, true);
  assert (select ig.plus from public.instance_guests ig join public.guests g on g.id = ig.guest
          where g.phone = '+15555550199') = 0, 'plus 0 sets zero';
  perform public.guest_rsvp_open_join(link, 'Pat', '+15555550199', 'yes', null, false, 2, true);
  perform public.guest_rsvp_open_join(link, 'Pat', '+15555550199', 'yes', null, false, null, true);
  assert (select ig.plus from public.instance_guests ig join public.guests g on g.id = ig.guest
          where g.phone = '+15555550199') = 0, 'plus null sets zero';

  -- out of range, or p_set_plus null: bad_request, nothing written
  perform public.guest_rsvp_open_join(link, 'Pat', '+15555550199', 'yes', null, false, 2, true);
  begin
    perform public.guest_rsvp_open_join(link, 'Pat', '+15555550199', 'maybe', null, false, 10, true);
    raise exception 'FAIL: plus 10 accepted';
  exception when raise_exception then
    get stacked diagnostics msg = message_text;
    assert msg = 'bad_request', 'plus 10 is bad_request, got ' || msg;
  end;
  begin
    perform public.guest_rsvp_open_join(link, 'Pat', '+15555550199', 'maybe', null, false, -1, true);
    raise exception 'FAIL: plus -1 accepted';
  exception when raise_exception then
    get stacked diagnostics msg = message_text;
    assert msg = 'bad_request', 'plus -1 is bad_request, got ' || msg;
  end;
  begin
    perform public.guest_rsvp_open_join(link, 'Pat', '+15555550199', 'maybe', null, false, 1, null);
    raise exception 'FAIL: null p_set_plus accepted';
  exception when raise_exception then
    get stacked diagnostics msg = message_text;
    assert msg = 'bad_request', 'null p_set_plus is bad_request, got ' || msg;
  end;
  assert (select ig.status || '|' || ig.plus from public.instance_guests ig join public.guests g on g.id = ig.guest
          where g.phone = '+15555550199') = 'yes|2', 'refused calls wrote nothing';

  -- the host-added guest answers through the link with plus-ones: stored,
  -- but not held by the link (it did not create them)
  perform public.guest_rsvp_open_join(link, 'Sam', '+15555550100', 'yes', null, false, 4, true);
  assert (select status || '|' || plus from public.instance_guests where guest = sam and instance = e1) = 'yes|4',
    'host-added guest plus set through the open link';
  assert (select open_link from public.guests where id = sam) is null, 'a reused guest is not marked';
  assert public.guest_open_link_plus(link) = 2, 'only plus-ones of guests the link created count';
end $$;

-- ── the cap: guests created + plus-ones held <= max_guests (6) ──
do $$
declare
  link constant text := repeat('c', 64);
  e1 constant uuid := '00000000-0000-4000-8000-0000000000e1';
  pat uuid := (select id from public.guests where phone = '+15555550199');
  msg text;
begin
  -- now: 1 created + 2 held = 3
  assert (select guests_created from public.instance_open_links) = 1, 'one guest created so far';

  -- a new guest bringing three would make 3 + 1 + 3 = 7: refused, nothing written
  begin
    perform public.guest_rsvp_open_join(link, 'Lee Example', '+15555550198', 'yes', 'hi', true, 3, true);
    raise exception 'FAIL: join over the cap accepted';
  exception when raise_exception then
    get stacked diagnostics msg = message_text;
    assert msg = 'not_found', 'over the cap is not_found, got ' || msg;
  end;
  assert not exists (select 1 from public.guests where phone = '+15555550198'), 'refused join created no guest';
  assert (select guests_created from public.instance_open_links) = 1, 'refused join did not count';

  -- with a no it holds nothing: 3 + 1 = 4, accepted, plus stored as given
  perform public.guest_rsvp_open_join(link, 'Lee Example', '+15555550198', 'no', null, false, 3, true);
  assert (select ig.plus from public.instance_guests ig join public.guests g on g.id = ig.guest
          where g.phone = '+15555550198') = 3, 'plus stored on a no';
  assert public.guest_open_link_plus(link) = 2, 'a no holds nothing';
  -- switching that no to yes through the link would make 4 + 3 = 7: refused
  begin
    perform public.guest_rsvp_open_join(link, 'Lee', '+15555550198', 'yes');
    raise exception 'FAIL: status change over the cap accepted';
  exception when raise_exception then
    get stacked diagnostics msg = message_text;
    assert msg = 'not_found', 'status change over the cap is not_found, got ' || msg;
  end;
  assert (select ig.status from public.instance_guests ig join public.guests g on g.id = ig.guest
          where g.phone = '+15555550198') = 'no', 'refused update wrote nothing';
  -- yes with one plus-one: 4 + 1 = 5
  perform public.guest_rsvp_open_join(link, 'Lee', '+15555550198', 'yes', null, false, 1, true);
  -- Pat raises to 3 through the link: 5 + 1 = 6 = max, accepted
  perform public.guest_rsvp_open_join(link, 'Pat', '+15555550199', 'yes', null, false, 3, true);
  assert (select guests_created from public.instance_open_links) + public.guest_open_link_plus(link) = 6, 'exactly full';

  -- full refuses everyone through the link, even a status-only change
  begin
    perform public.guest_rsvp_open_join(link, 'Pat', '+15555550199', 'maybe');
    raise exception 'FAIL: full link accepted an answer';
  exception when raise_exception then
    get stacked diagnostics msg = message_text;
    assert msg = 'not_found', 'full link is not_found, got ' || msg;
  end;

  -- the guest's own link (guest_rsvp_answer): lowering is always allowed
  assert public.guest_rsvp_answer(pat, e1, 'yes', null, false, 1, true), 'lowering accepted';
  -- raising by 3 would make 4 + 3 = 7: refused, nothing written
  assert not public.guest_rsvp_answer(pat, e1, 'yes', 'note too', true, 4, true), 'raising over the cap refused';
  assert (select status || '|' || plus || '|' || coalesce(note, '<null>') from public.instance_guests
          where guest = pat and instance = e1) = 'yes|1|<null>', 'refused answer wrote nothing';
  -- raising by 2: 4 + 2 = 6, accepted
  assert public.guest_rsvp_answer(pat, e1, 'maybe', null, false, 3, true), 'raising within the cap accepted';
  -- a closed link still holds its places
  update public.instance_open_links set closed_at = now();
  assert not public.guest_rsvp_answer(pat, e1, 'maybe', null, false, 4, true), 'cap applies after the link is closed';
  -- the host-added guest is not held by the link: any change is fine
  assert public.guest_rsvp_answer('00000000-0000-4000-8000-0000000000b1', e1, 'yes', null, false, 9, true),
    'host-added guest not capped';
end $$;

-- ── the guest's own answer: set, keep when omitted, zero, note, refuse ──
do $$
declare
  sam constant uuid := '00000000-0000-4000-8000-0000000000b1';
  e2 constant uuid := '00000000-0000-4000-8000-0000000000e2';
  msg text;
begin
  assert public.guest_rsvp_answer(sam, e2, 'yes', 'Bringing chips', true, 2, true), 'set';
  assert (select status || '|' || plus || '|' || note from public.instance_guests where guest = sam and instance = e2)
    = 'yes|2|Bringing chips', 'status, plus and note stored';
  assert public.guest_rsvp_answer(sam, e2, 'no'), 'status only';
  assert (select status || '|' || plus || '|' || note from public.instance_guests where guest = sam and instance = e2)
    = 'no|2|Bringing chips', 'omitted plus and note kept';
  assert public.guest_rsvp_answer(sam, e2, 'yes', null, false, null, true), 'null plus';
  assert (select plus from public.instance_guests where guest = sam and instance = e2) = 0, 'null sets zero';
  assert public.guest_rsvp_answer(sam, e2, 'yes', '  ', true, 2, true), 'blank note';
  assert (select coalesce(note, '<null>') || '|' || plus from public.instance_guests where guest = sam and instance = e2)
    = '<null>|2', 'blank clears the note';
  assert not public.guest_rsvp_answer(sam, '00000000-0000-4000-8000-0000000000ff', 'yes'), 'not on the event: false';
  begin
    perform public.guest_rsvp_answer(sam, e2, 'yes', null, false, 10, true);
    raise exception 'FAIL: plus 10 accepted';
  exception when raise_exception then
    get stacked diagnostics msg = message_text;
    assert msg = 'bad_request', 'plus 10 is bad_request, got ' || msg;
  end;
  begin
    perform public.guest_rsvp_answer(sam, e2, 'invited');
    raise exception 'FAIL: invited accepted';
  exception when raise_exception then
    get stacked diagnostics msg = message_text;
    assert msg = 'bad_request', 'invited is bad_request, got ' || msg;
  end;
end $$;

-- ── who may call what, and who may write open_link ──
do $$
declare
  fn text;
begin
  foreach fn in array array[
    'public.guest_rsvp_open_join(text, text, text, text, text, boolean, integer, boolean)',
    'public.guest_rsvp_answer(uuid, uuid, text, text, boolean, integer, boolean)',
    'public.guest_open_link_plus(text)'
  ] loop
    assert has_function_privilege('service_role', fn, 'execute'), 'service_role may call ' || fn;
    assert not has_function_privilege('anon', fn, 'execute'), 'anon may not call ' || fn;
    assert not has_function_privilege('authenticated', fn, 'execute'), 'authenticated may not call ' || fn;
  end loop;
  assert to_regprocedure('public.guest_rsvp_open_join(text, text, text, text, text, boolean)') is null,
    'no 6-argument overload left';
  assert not has_column_privilege('authenticated', 'public.guests', 'open_link', 'update'), 'hosts cannot set open_link';
  assert not has_column_privilege('authenticated', 'public.guests', 'open_link', 'insert'), 'hosts cannot insert open_link';
  assert not has_column_privilege('anon', 'public.instance_guests', 'plus', 'select'), 'anon cannot read plus';
end $$;

set local role authenticated;

select
  set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}', true),
  set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-0000000000a1', true);

do $$
begin
  assert (select plus from public.instance_guests where guest = '00000000-0000-4000-8000-0000000000b1'
          and instance = '00000000-0000-4000-8000-0000000000e1') = 9, 'host reads their guest''s plus-ones';
end $$;

reset role;

-- ── claim: plus-ones fold into the new member row's note ──
update public.instance_guests set status = 'maybe', plus = 1, note = null
where guest = '00000000-0000-4000-8000-0000000000b1' and instance = '00000000-0000-4000-8000-0000000000e2';

update public.instance_guests set status = 'no', plus = 3, note = 'Out of town'
where guest = '00000000-0000-4000-8000-0000000000b1' and instance = '00000000-0000-4000-8000-0000000000e3';

update public.instance_guests set status = 'yes', plus = 2, note = 'Bringing chips'
where guest = '00000000-0000-4000-8000-0000000000b1' and instance = '00000000-0000-4000-8000-0000000000e1';

-- Sam signs up: the profile insert runs the claim
insert into
  public.profiles (id, first_name, last_name, phone)
values
  ('00000000-0000-4000-8000-0000000000c1', 'Sam', 'Example', '15555550100');

do $$
declare
  sam_user constant uuid := '00000000-0000-4000-8000-0000000000c1';
begin
  assert (select claimed_by from public.guests where id = '00000000-0000-4000-8000-0000000000b1') = sam_user, 'claimed';
  assert (select status::text || '|' || note from public.instance_members
          where member = sam_user and instance = '00000000-0000-4000-8000-0000000000e1') = 'yes|Bringing chips (+2)',
    'plus-ones appended to the note';
  assert (select status::text || '|' || note from public.instance_members
          where member = sam_user and instance = '00000000-0000-4000-8000-0000000000e2') = 'maybe|+1',
    'no note: the note is +N';
  assert (select status::text || '|' || note from public.instance_members
          where member = sam_user and instance = '00000000-0000-4000-8000-0000000000e3') = 'no|Out of town',
    'plus-ones on a no are not copied';
  assert (select plus from public.instance_guests where guest = '00000000-0000-4000-8000-0000000000b1'
          and instance = '00000000-0000-4000-8000-0000000000e1') = 2, 'guest row kept as it was';
end $$;

rollback;

-- existing member row wins, plus-ones not folded into it
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

insert into
  public.profiles (id, first_name, last_name, phone)
values
  ('00000000-0000-4000-8000-0000000000a1', 'Host', 'One', '15555550101'),
  ('00000000-0000-4000-8000-0000000000c1', 'Sam', 'Example', '15555550100');

insert into
  public.instances (id, created_by, title, location_description, rally_point, status, visibility)
values
  ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000a1', 'One live', 'Somewhere', 'POINT(-75.16 39.95)', 'live', 'private');

insert into
  public.instance_members (instance, member, status, created_by, note)
values
  ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000c1', 'yes', '00000000-0000-4000-8000-0000000000c1', 'Member note');

insert into
  public.guests (id, host, name, phone)
values
  ('00000000-0000-4000-8000-0000000000b1', '00000000-0000-4000-8000-0000000000a1', 'Sam Example', '+15555550100');

insert into
  public.instance_guests (instance, guest, status, note, plus)
values
  ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000b1', 'yes', 'Guest note', 2);

do $$
begin
  assert public.guest_claim_for_user('00000000-0000-4000-8000-0000000000c1') = 1, 'one guest row claimed';
  assert (select note from public.instance_members
          where member = '00000000-0000-4000-8000-0000000000c1'
            and instance = '00000000-0000-4000-8000-0000000000e1') = 'Member note',
    'existing member row wins, no plus-ones folded in';
end $$;

rollback;

select 'guests_plus: all checks passed' as result;
