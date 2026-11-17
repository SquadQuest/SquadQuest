-- Checks for guests who become members (tables/instance_guests_claim.sql).
--
-- Runs against a LOCAL database that has the SquadQuest schema loaded (see
-- docs/guest-rsvp.md § Testing). Everything happens inside one transaction
-- that is rolled back, so it leaves nothing behind. Any failed check raises
-- and stops the script (run psql with -v ON_ERROR_STOP=1).
--
-- Invented people and numbers only (555-01xx).
--
-- Needs GoTrue's auth schema (auth.sessions, auth.mfa_amr_claims), which the
-- local stack's auth container creates on start.
--
--   a1 Host One, a2 Host Two         hosts
--   c1 Sam   15555550100  signed in by SMS code                  -> claims
--   c2 Una   15555550110  phone never confirmed                  -> no claim
--   c3 Pam   15555550120  confirmed by autoconfirm, password only -> no claim
--   c4 Max   15555550130  has a profile first, verified later    -> claims via guest_claim_mine()
--   c5 Flo   15555550140  verified, claim fails mid-way          -> signup still works
--   c6 Ray   15555550150  code sign-in, then phone changed       -> no claim
--   c7 Eve   15555550160  code sign-in, but has an email         -> no claim
begin;

-- phone_confirmed_at one hour ago; sign-ins relative to it
insert into
  auth.users (id, aud, role, phone, phone_confirmed_at, email, raw_app_meta_data)
values
  ('00000000-0000-4000-8000-0000000000a1', 'authenticated', 'authenticated', '15555550101', now() - interval '1 hour', null, '{}'),
  ('00000000-0000-4000-8000-0000000000a2', 'authenticated', 'authenticated', '15555550102', now() - interval '1 hour', null, '{}'),
  -- Host Two invited Sam as a friend by phone before: on-profile-insert makes that request
  ('00000000-0000-4000-8000-0000000000c1', 'authenticated', 'authenticated', '15555550100', now() - interval '1 hour', null, '{"invite_friends":["00000000-0000-4000-8000-0000000000a2"]}'),
  ('00000000-0000-4000-8000-0000000000c2', 'authenticated', 'authenticated', '15555550110', null, null, '{}'),
  ('00000000-0000-4000-8000-0000000000c3', 'authenticated', 'authenticated', '15555550120', now() - interval '1 hour', null, '{}'),
  ('00000000-0000-4000-8000-0000000000c4', 'authenticated', 'authenticated', '15555550130', null, null, '{}'),
  ('00000000-0000-4000-8000-0000000000c5', 'authenticated', 'authenticated', '15555550140', now() - interval '1 hour', null, '{}'),
  ('00000000-0000-4000-8000-0000000000c6', 'authenticated', 'authenticated', '15555550150', now() - interval '1 hour', null, '{}'),
  ('00000000-0000-4000-8000-0000000000c7', 'authenticated', 'authenticated', '15555550160', now() - interval '1 hour', 'eve@example.com', '{}');

-- one session per user (session id = user id with d in place of 0 at the front)
insert into
  auth.sessions (id, user_id, created_at, updated_at)
select
  overlay(id::text placing 'dddddddd' from 1 for 8)::uuid, id, now(), now()
from
  auth.users
where
  id::text like '00000000-0000-4000-8000-0000000000c_';

-- how each session was signed in, as GoTrue records it
insert into
  auth.mfa_amr_claims (id, session_id, authentication_method, created_at, updated_at)
select
  gen_random_uuid (), overlay(u::text placing 'dddddddd' from 1 for 8)::uuid, m, t, t
from
  (
    values
      ('00000000-0000-4000-8000-0000000000c1'::uuid, 'otp', now() - interval '59 minutes'),
      ('00000000-0000-4000-8000-0000000000c2'::uuid, 'otp', now() - interval '59 minutes'),
      ('00000000-0000-4000-8000-0000000000c3'::uuid, 'password', now() - interval '59 minutes'),
      ('00000000-0000-4000-8000-0000000000c4'::uuid, 'otp', now() - interval '2 hours'),
      ('00000000-0000-4000-8000-0000000000c5'::uuid, 'otp', now() - interval '59 minutes'),
      -- signed in by code two hours ago, phone changed (autoconfirmed) one hour ago
      ('00000000-0000-4000-8000-0000000000c6'::uuid, 'otp', now() - interval '2 hours'),
      ('00000000-0000-4000-8000-0000000000c7'::uuid, 'otp', now() - interval '59 minutes')
  ) as x (u, m, t);

insert into
  public.profiles (id, first_name, last_name, phone)
values
  ('00000000-0000-4000-8000-0000000000a1', 'Host', 'One', '15555550101'),
  ('00000000-0000-4000-8000-0000000000a2', 'Host', 'Two', '15555550102');

insert into
  public.instances (id, created_by, title, location_description, rally_point, status, visibility)
values
  ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000a1', 'One live', 'Somewhere', 'POINT(-75.16 39.95)', 'live', 'private'),
  ('00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-0000000000a1', 'One later', 'Somewhere', 'POINT(-75.16 39.95)', 'live', 'friends'),
  ('00000000-0000-4000-8000-0000000000e3', '00000000-0000-4000-8000-0000000000a1', 'One draft', 'Somewhere', 'POINT(-75.16 39.95)', 'draft', 'private'),
  ('00000000-0000-4000-8000-0000000000e6', '00000000-0000-4000-8000-0000000000a1', 'One canceled', 'Somewhere', 'POINT(-75.16 39.95)', 'canceled', 'public'),
  ('00000000-0000-4000-8000-0000000000e4', '00000000-0000-4000-8000-0000000000a2', 'Two live', 'Elsewhere', 'POINT(-75.16 39.95)', 'live', 'public'),
  ('00000000-0000-4000-8000-0000000000e5', '00000000-0000-4000-8000-0000000000a2', 'Two private', 'Elsewhere', 'POINT(-75.16 39.95)', 'live', 'private');

insert into
  public.guests (id, host, name, phone)
values
  ('00000000-0000-4000-8000-0000000000b1', '00000000-0000-4000-8000-0000000000a1', 'Sam Example', '+15555550100'),
  ('00000000-0000-4000-8000-0000000000b2', '00000000-0000-4000-8000-0000000000a2', 'Sammy', '+15555550100'),
  ('00000000-0000-4000-8000-0000000000b3', '00000000-0000-4000-8000-0000000000a1', 'Una Example', '+15555550110'),
  ('00000000-0000-4000-8000-0000000000b4', '00000000-0000-4000-8000-0000000000a1', 'Pam Example', '+15555550120'),
  ('00000000-0000-4000-8000-0000000000b5', '00000000-0000-4000-8000-0000000000a1', 'Max Example', '+15555550130'),
  ('00000000-0000-4000-8000-0000000000b6', '00000000-0000-4000-8000-0000000000a2', 'Max Two', '+15555550130'),
  ('00000000-0000-4000-8000-0000000000b7', '00000000-0000-4000-8000-0000000000a1', 'Flo Example', '+15555550140'),
  ('00000000-0000-4000-8000-0000000000b8', '00000000-0000-4000-8000-0000000000a2', 'Nobody', '+15555550199'),
  ('00000000-0000-4000-8000-0000000000b9', '00000000-0000-4000-8000-0000000000a1', 'Ray Example', '+15555550150'),
  ('00000000-0000-4000-8000-0000000000ba', '00000000-0000-4000-8000-0000000000a1', 'Eve Example', '+15555550160');

insert into
  public.instance_guests (instance, guest, status)
values
  ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000b1', 'yes'),
  ('00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-0000000000b1', 'invited'),
  ('00000000-0000-4000-8000-0000000000e3', '00000000-0000-4000-8000-0000000000b1', 'maybe'),
  ('00000000-0000-4000-8000-0000000000e6', '00000000-0000-4000-8000-0000000000b1', 'no'),
  ('00000000-0000-4000-8000-0000000000e4', '00000000-0000-4000-8000-0000000000b2', 'maybe'),
  ('00000000-0000-4000-8000-0000000000e5', '00000000-0000-4000-8000-0000000000b2', 'yes'),
  ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000b3', 'yes'),
  ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000b4', 'yes'),
  ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000b5', 'yes'),
  ('00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-0000000000b5', 'maybe'),
  ('00000000-0000-4000-8000-0000000000e4', '00000000-0000-4000-8000-0000000000b6', 'no'),
  ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000b7', 'yes'),
  ('00000000-0000-4000-8000-0000000000e4', '00000000-0000-4000-8000-0000000000b8', 'yes'),
  ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000b9', 'yes'),
  ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000ba', 'yes');

-- ── phone not proven by an SMS code: signup claims nothing ──
insert into
  public.profiles (id, first_name, last_name, phone)
values
  -- the client could write any phone here; the claim never reads it
  ('00000000-0000-4000-8000-0000000000c2', 'Una', 'Example', '15555550100'),
  ('00000000-0000-4000-8000-0000000000c3', 'Pam', 'Example', '15555550120'),
  ('00000000-0000-4000-8000-0000000000c6', 'Ray', 'Example', '15555550150'),
  ('00000000-0000-4000-8000-0000000000c7', 'Eve', 'Example', '15555550160');

do $$
begin
  assert (select count(*) from public.guests where claimed_by is not null) = 0,
    'unverified or password accounts claim nothing';
  assert (select count(*) from public.instance_members) = 0, 'no member rows';
  assert (select count(*) from public.friends) = 0, 'no friend requests';
  assert public.guest_claim_for_user('00000000-0000-4000-8000-0000000000c2') = 0, 'explicit call: unverified';
  assert public.guest_claim_for_user('00000000-0000-4000-8000-0000000000c3') = 0, 'explicit call: password';
  assert public.guest_claim_for_user('00000000-0000-4000-8000-0000000000c6') = 0, 'explicit call: phone changed after code';
  assert public.guest_claim_for_user('00000000-0000-4000-8000-0000000000c7') = 0, 'explicit call: has an email';
  assert public.guest_claim_for_user('00000000-0000-4000-8000-0000000000c1') = 0, 'explicit call: no profile yet';
  assert public.guest_claim_for_user(null) = 0, 'explicit call: null';
end $$;

-- ── verified signup: the profile insert claims every host's guest row ──
insert into
  public.profiles (id, first_name, last_name, phone)
values
  ('00000000-0000-4000-8000-0000000000c1', 'Sam', 'Example', '15555550100');

do $$
declare
  sam constant uuid := '00000000-0000-4000-8000-0000000000c1';
  h1 constant uuid := '00000000-0000-4000-8000-0000000000a1';
  h2 constant uuid := '00000000-0000-4000-8000-0000000000a2';
begin
  assert (select count(*) from public.guests where claimed_by = sam and claimed_at is not null) = 2,
    'both hosts'' guest rows with the phone are claimed';
  assert (select array_agg(id::text order by id) from public.guests where claimed_by is not null)
    = array['00000000-0000-4000-8000-0000000000b1', '00000000-0000-4000-8000-0000000000b2'],
    'only that phone''s guest rows';

  -- status mapping, created_by the host, drafts skipped
  assert (
    select array_agg(instance::text || ':' || status::text || ':' || (created_by = case when instance::text like '%e4' or instance::text like '%e5' then h2 else h1 end)::text order by instance)
    from public.instance_members where member = sam
  ) = array[
    '00000000-0000-4000-8000-0000000000e1:yes:true',
    '00000000-0000-4000-8000-0000000000e2:invited:true',
    '00000000-0000-4000-8000-0000000000e4:maybe:true',
    '00000000-0000-4000-8000-0000000000e5:yes:true',
    '00000000-0000-4000-8000-0000000000e6:no:true'
  ], 'answers become member rows with the same status, created by the host, no draft';

  -- friend request from Host One; none from Host Two (in invite_friends)
  assert (select count(*) from public.friends where requester = h1 and requestee = sam and status = 'requested') = 1,
    'pending friend request from host one';
  assert (select count(*) from public.friends where h2 in (requester, requestee)) = 0,
    'host two is left to on-profile-insert (invite_friends)';

  -- what the claim made is identifiable for a rollback: created_at = claimed_at
  assert (
    select count(*) from public.instance_members im
    join public.guests g on g.claimed_by = im.member and g.host = im.created_by and g.claimed_at = im.created_at
    where im.member = sam
  ) = 5, 'claimed member rows carry the claim time';
  assert (
    select count(*) from public.friends f
    join public.guests g on g.claimed_by = f.requestee and g.host = f.requester and g.claimed_at = f.created_at
  ) = 1, 'claimed friend request carries the claim time';

  -- guest-side answers are left as they were
  assert (select status from public.instance_guests
          where guest = '00000000-0000-4000-8000-0000000000b1' and instance = '00000000-0000-4000-8000-0000000000e1') = 'yes',
    'guest answer kept for the record';
end $$;

-- ── idempotent: running again changes nothing ──
create temp table snapshot as
select
  (select count(*) from public.instance_members) as members,
  (select count(*) from public.friends) as friends,
  (select array_agg(claimed_at order by id) from public.guests) as claimed_ats;

do $$
begin
  assert public.guest_claim_for_user('00000000-0000-4000-8000-0000000000c1') = 0, 'second run claims nothing';
  assert (select members from snapshot) = (select count(*) from public.instance_members), 'members unchanged';
  assert (select friends from snapshot) = (select count(*) from public.friends), 'friends unchanged';
  assert (select claimed_ats from snapshot) = (select array_agg(claimed_at order by id) from public.guests), 'claimed_at unchanged';
end $$;

-- ── existing member row wins; existing friendship is left alone ──
-- Max already has a profile (phone not yet confirmed), is friends with Host
-- One, and has answered E1 himself.
insert into
  public.profiles (id, first_name, last_name, phone)
values
  ('00000000-0000-4000-8000-0000000000c4', 'Max', 'Example', '15555550130');

insert into
  public.friends (requester, requestee, status)
values
  ('00000000-0000-4000-8000-0000000000c4', '00000000-0000-4000-8000-0000000000a1', 'accepted');

insert into
  public.instance_members (instance, member, status, created_by)
values
  ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000c4', 'no', '00000000-0000-4000-8000-0000000000c4');

do $$
begin
  assert (select count(*) from public.guests where claimed_by = '00000000-0000-4000-8000-0000000000c4') = 0,
    'nothing claimed while the phone is unconfirmed';
end $$;

-- Max confirms his number by SMS code (GoTrue sets phone_confirmed_at, then
-- records the 'otp' sign-in), then the app, or anything signed in as him,
-- calls guest_claim_mine()
update auth.users set phone_confirmed_at = now() - interval '1 minute' where id = '00000000-0000-4000-8000-0000000000c4';

do $$
begin
  assert public.guest_claim_for_user('00000000-0000-4000-8000-0000000000c4') = 0,
    'an older code sign-in does not prove the newly confirmed phone';
end $$;

update auth.mfa_amr_claims set updated_at = now()
where session_id = 'dddddddd-0000-4000-8000-0000000000c4' and authentication_method = 'otp';

set local role authenticated;

select
  set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000c4","role":"authenticated"}', true),
  set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-0000000000c4', true);

do $$
begin
  assert public.guest_claim_mine() = 2, 'Max claims his two guest rows';
  assert public.guest_claim_mine() = 0, 'and again claims nothing';
end $$;

reset role;

do $$
declare
  max_ constant uuid := '00000000-0000-4000-8000-0000000000c4';
begin
  assert (select status from public.instance_members where member = max_ and instance = '00000000-0000-4000-8000-0000000000e1') = 'no',
    'existing member row wins over the guest answer';
  assert (select created_by from public.instance_members where member = max_ and instance = '00000000-0000-4000-8000-0000000000e1') = max_,
    'existing member row untouched';
  assert (select status from public.instance_members where member = max_ and instance = '00000000-0000-4000-8000-0000000000e2') = 'maybe',
    'other answers still claimed';
  assert (select status from public.instance_members where member = max_ and instance = '00000000-0000-4000-8000-0000000000e4') = 'no',
    'other host''s answer claimed';
  assert (select count(*) from public.friends where '00000000-0000-4000-8000-0000000000a1' in (requester, requestee) and max_ in (requester, requestee)) = 1,
    'existing friendship with host one left alone';
  assert (select count(*) from public.friends where requester = '00000000-0000-4000-8000-0000000000a2' and requestee = max_ and status = 'requested') = 1,
    'pending request from host two';
end $$;

-- ── a failing claim never blocks signup ──
alter table public.instance_guests rename to instance_guests_away;

insert into
  public.profiles (id, first_name, last_name, phone)
values
  ('00000000-0000-4000-8000-0000000000c5', 'Flo', 'Example', '15555550140');

alter table public.instance_guests_away rename to instance_guests;

do $$
begin
  assert (select count(*) from public.profiles where id = '00000000-0000-4000-8000-0000000000c5') = 1, 'profile created';
  assert (select claimed_by from public.guests where id = '00000000-0000-4000-8000-0000000000b7') is null,
    'failed claim rolled back, guest still unclaimed';
  -- the operator can run it again once fixed
  assert public.guest_claim_for_user('00000000-0000-4000-8000-0000000000c5') = 1, 'retry claims';
end $$;

-- ── RLS and privileges ──
set local role authenticated;

-- as Sam, the new member
select
  set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000c1","role":"authenticated"}', true),
  set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-0000000000c1', true);

do $$
begin
  assert (select count(*) from public.guests) = 0, 'a member cannot read guest rows, even ones they claimed';
  assert (select count(*) from public.instance_guests) = 0, 'a member cannot read guest answers';
  assert (select count(*) from public.instance_members where member = '00000000-0000-4000-8000-0000000000c1') = 5,
    'a member sees their own RSVPs';
  begin
    perform public.guest_claim_for_user('00000000-0000-4000-8000-0000000000c2');
    raise exception 'FAIL: a member ran the claim for someone else';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.guest_claim_verified_phone('00000000-0000-4000-8000-0000000000c2');
    raise exception 'FAIL: a member read someone''s verified phone';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.guests set claimed_by = null;
    raise exception 'FAIL: a member changed claimed_by';
  exception when insufficient_privilege then null;
  end;
end $$;

-- as Host One
select
  set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}', true),
  set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-0000000000a1', true);

do $$
begin
  assert (select count(*) from public.guests) = 7, 'host one still sees exactly their own guests';
  assert (select claimed_by from public.guests where id = '00000000-0000-4000-8000-0000000000b1')
    = '00000000-0000-4000-8000-0000000000c1', 'host sees who claimed their guest';
  assert (select count(*) from public.guests where host <> '00000000-0000-4000-8000-0000000000a1') = 0,
    'never another host''s guest rows';
  begin
    update public.guests set claimed_by = null, claimed_at = null where id = '00000000-0000-4000-8000-0000000000b1';
    raise exception 'FAIL: a host changed claimed_by';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;

set local role anon;

do $$
begin
  begin
    perform public.guest_claim_mine();
    raise exception 'FAIL: anon ran the claim';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;

select 'guests_claim: all checks passed' as result;

rollback;
