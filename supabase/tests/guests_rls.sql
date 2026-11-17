-- Row level security checks for guests and instance_guests.
--
-- Runs against a LOCAL database that has the SquadQuest schema loaded (see
-- docs/guest-rsvp.md § Testing). Everything happens inside one transaction
-- that is rolled back, so it leaves nothing behind. Any failed check raises
-- and stops the script (run psql with -v ON_ERROR_STOP=1).
--
-- Invented people only: Host One, Host Two, Sam Example.
begin;

insert into
  auth.users (id, aud, role)
values
  ('00000000-0000-4000-8000-0000000000a1', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000a2', 'authenticated', 'authenticated');

insert into
  public.profiles (id, first_name, last_name, phone)
values
  ('00000000-0000-4000-8000-0000000000a1', 'Host', 'One', '+15555550101'),
  ('00000000-0000-4000-8000-0000000000a2', 'Host', 'Two', '+15555550102');

insert into
  public.instances (id, created_by, title, location_description, rally_point)
values
  ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000a1', 'Host One party', 'Somewhere', 'POINT(-75.16 39.95)'),
  ('00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-0000000000a2', 'Host Two party', 'Elsewhere', 'POINT(-75.16 39.95)');

-- ── as Host One ──────────────────────────────────────────────────────
set local role authenticated;

select
  set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}', true),
  -- older auth.uid() reads the single claim
  set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-0000000000a1', true);

insert into
  public.guests (id, name, phone)
values
  ('00000000-0000-4000-8000-0000000000b1', 'Sam Example', '+15555550100');

do $$
declare t text;
begin
  select token into t from public.guests where id = '00000000-0000-4000-8000-0000000000b1';
  assert t ~ '^[0-9a-f]{64}$', 'token is 64 hex characters, generated server side';
  assert (select host from public.guests where id = '00000000-0000-4000-8000-0000000000b1')
    = '00000000-0000-4000-8000-0000000000a1', 'host defaults to the caller';
end $$;

-- a host cannot choose the token
do $$
begin
  begin
    insert into public.guests (name, token) values ('Sam Example', 'chosen');
    raise exception 'FAIL: host supplied a token';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.guests set token = 'chosen' where id = '00000000-0000-4000-8000-0000000000b1';
    raise exception 'FAIL: host changed a token';
  exception when insufficient_privilege then null;
  end;
end $$;

-- a host cannot create a guest for someone else
do $$
begin
  begin
    insert into public.guests (host, name) values ('00000000-0000-4000-8000-0000000000a2', 'Sam Example');
    raise exception 'FAIL: guest created for another host';
  exception when insufficient_privilege then null;
  end;
end $$;

-- the same phone twice for one host is refused (idempotency backstop)
do $$
begin
  begin
    insert into public.guests (name, phone) values ('Sam Again', '+15555550100');
    raise exception 'FAIL: duplicate phone accepted';
  exception when unique_violation then null;
  end;
end $$;

-- attach to own event: allowed; to someone else's event: refused
insert into
  public.instance_guests (instance, guest)
values
  ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000b1');

do $$
begin
  begin
    insert into public.instance_guests (instance, guest)
    values ('00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-0000000000b1');
    raise exception 'FAIL: guest attached to another host''s event';
  exception when insufficient_privilege then null;
  end;
  assert (select status from public.instance_guests) = 'invited', 'status defaults to invited';
end $$;

-- ── as Host Two ──────────────────────────────────────────────────────
select
  set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a2","role":"authenticated"}', true),
  -- older auth.uid() reads the single claim
  set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-0000000000a2', true);

do $$
begin
  assert (select count(*) from public.guests) = 0, 'Host Two cannot see Host One''s guests';
  assert (select count(*) from public.instance_guests) = 0, 'Host Two cannot see Host One''s guest rows';
  update public.guests set name = 'Taken' where id = '00000000-0000-4000-8000-0000000000b1';
  delete from public.instance_guests;
  begin
    -- Host Two's own event, Host One's guest
    insert into public.instance_guests (instance, guest)
    values ('00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-0000000000b1');
    raise exception 'FAIL: another host''s guest attached';
  exception when insufficient_privilege then null;
  end;
end $$;

-- ── anonymous ────────────────────────────────────────────────────────
reset role;

set local role anon;

do $$
begin
  begin
    perform 1 from public.guests;
    raise exception 'FAIL: anon read guests';
  exception when insufficient_privilege then null;
  end;
  begin
    perform 1 from public.instance_guests;
    raise exception 'FAIL: anon read instance_guests';
  exception when insufficient_privilege then null;
  end;
end $$;

-- ── back as owner: Host Two's attempts changed nothing ───────────────
reset role;

do $$
begin
  assert (select name from public.guests where id = '00000000-0000-4000-8000-0000000000b1') = 'Sam Example',
    'Host Two''s update was a no-op';
  assert (select count(*) from public.instance_guests) = 1, 'Host Two''s delete was a no-op';
  -- deleting the event cascades to its guest rows, never to the guest
  delete from public.instances where id = '00000000-0000-4000-8000-0000000000e1';
  assert (select count(*) from public.instance_guests) = 0, 'event delete cascades';
  assert (select count(*) from public.guests) = 1, 'guest survives event delete';
end $$;

-- ── open links ───────────────────────────────────────────────────────
insert into
  public.instances (id, created_by, title, location_description, rally_point)
values
  ('00000000-0000-4000-8000-0000000000e3', '00000000-0000-4000-8000-0000000000a1', 'Host One open party', 'Somewhere', 'POINT(-75.16 39.95)');

set local role authenticated;

select
  set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}', true),
  -- older auth.uid() reads the single claim
  set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-0000000000a1', true);

insert into
  public.instance_open_links (instance)
values
  ('00000000-0000-4000-8000-0000000000e3');

do $$
begin
  assert (select token from public.instance_open_links) ~ '^[0-9a-f]{64}$', 'open token generated server side';
  begin
    insert into public.instance_open_links (instance) values ('00000000-0000-4000-8000-0000000000e3');
    raise exception 'FAIL: second open link on one event';
  exception when unique_violation then null;
  end;
  begin
    insert into public.instance_open_links (instance) values ('00000000-0000-4000-8000-0000000000e2');
    raise exception 'FAIL: open link on another host''s event';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.instance_open_links (instance, token) values ('00000000-0000-4000-8000-0000000000e3', 'chosen');
    raise exception 'FAIL: host chose an open token';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.guest_rsvp_open_join('x', 'Sam Example', null, 'yes');
    raise exception 'FAIL: authenticated user called the join function';
  exception when insufficient_privilege then null;
  end;
end $$;

select
  set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a2","role":"authenticated"}', true),
  -- older auth.uid() reads the single claim
  set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-0000000000a2', true);

do $$
begin
  assert (select count(*) from public.instance_open_links) = 0, 'Host Two cannot see Host One''s open link';
end $$;

reset role;

set local role anon;

do $$
begin
  begin
    perform 1 from public.instance_open_links;
    raise exception 'FAIL: anon read open links';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.guest_rsvp_open_join('x', 'Sam Example', null, 'yes');
    raise exception 'FAIL: anon called the join function';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;

set local role service_role;

do $$
declare
  link text;
  t text;
  msg text;
begin
  select token into link from public.instance_open_links;

  t := public.guest_rsvp_open_join(link, '  Pat Example ', '+15555550199', 'maybe');
  assert t ~ '^[0-9a-f]{64}$', 'join returns the new guest token';
  assert (select name from public.guests where token = t) = 'Pat Example', 'name trimmed';
  assert (select host from public.guests where token = t) = '00000000-0000-4000-8000-0000000000a1', 'guest belongs to the event host';
  assert (select ig.status from public.instance_guests ig join public.guests g on g.id = ig.guest where g.token = t) = 'maybe', 'answer recorded';
  assert (select guests_created from public.instance_open_links) = 1, 'join counted';

  begin
    perform public.guest_rsvp_open_join(link, 'Pat Again', '+15555550199', 'yes');
    raise exception 'FAIL: duplicate phone joined';
  exception when raise_exception then
    get stacked diagnostics msg = message_text;
    assert msg = 'conflict', 'duplicate phone is conflict, got ' || msg;
  end;

  begin
    perform public.guest_rsvp_open_join(link, '', null, 'yes');
    raise exception 'FAIL: empty name joined';
  exception when raise_exception then
    get stacked diagnostics msg = message_text;
    assert msg = 'bad_request', 'empty name is bad_request, got ' || msg;
  end;

  begin
    perform public.guest_rsvp_open_join('nope', 'Lee Example', null, 'yes');
    raise exception 'FAIL: unknown link joined';
  exception when raise_exception then
    get stacked diagnostics msg = message_text;
    assert msg = 'not_found', 'unknown link is not_found, got ' || msg;
  end;

  -- cap reached
  update public.instance_open_links set max_guests = 1;
  begin
    perform public.guest_rsvp_open_join(link, 'Lee Example', null, 'yes');
    raise exception 'FAIL: joined past the cap';
  exception when raise_exception then
    get stacked diagnostics msg = message_text;
    assert msg = 'not_found', 'full link is not_found, got ' || msg;
  end;
  update public.instance_open_links set max_guests = 300;

  -- canceled event
  update public.instances set status = 'canceled' where id = '00000000-0000-4000-8000-0000000000e3';
  begin
    perform public.guest_rsvp_open_join(link, 'Lee Example', null, 'yes');
    raise exception 'FAIL: joined a canceled event';
  exception when raise_exception then
    get stacked diagnostics msg = message_text;
    assert msg = 'not_found', 'canceled event is not_found, got ' || msg;
  end;
  update public.instances set status = 'live' where id = '00000000-0000-4000-8000-0000000000e3';

  -- closed link
  update public.instance_open_links set closed_at = now();
  begin
    perform public.guest_rsvp_open_join(link, 'Lee Example', null, 'yes');
    raise exception 'FAIL: joined a closed link';
  exception when raise_exception then
    get stacked diagnostics msg = message_text;
    assert msg = 'not_found', 'closed link is not_found, got ' || msg;
  end;
end $$;

reset role;

select
  'guests_rls: all checks passed' as result;

rollback;
