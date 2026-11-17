-- Guests: people an organizer has invited who do not have a SquadQuest
-- account. A guest belongs to the organizer (host) who added them and answers
-- through a private link carrying `token`, via the `guest-rsvp` function.
--
-- Purely additive: no existing table, policy or function refers to this
-- table, so v1 clients never see its rows. See docs/guest-rsvp.md.
create table
  public.guests (
    id uuid not null default gen_random_uuid (),
    created_at timestamp with time zone not null default now(),
    host uuid not null default auth.uid (),
    name text not null,
    phone text null,
    -- 244 random bits as 64 hex characters, generated here and never by a
    -- client (see the column grants below). gen_random_uuid() is the same
    -- generator instances.id already relies on in production.
    token text not null default replace(
      gen_random_uuid ()::text || gen_random_uuid ()::text,
      '-',
      ''
    ),
    constraint guests_pkey primary key (id),
    constraint guests_token_key unique (token),
    constraint guests_host_fkey foreign key (host) references profiles (id) on delete cascade,
    constraint guests_name_length check (char_length(name) between 1 and 100),
    constraint guests_phone_e164 check (phone is null or phone ~ '^\+[1-9][0-9]{6,14}$')
  );

-- one guest per phone per host: what makes adding a guest idempotent
create unique index guests_host_phone_key on public.guests (host, phone)
where
  phone is not null;

create index guests_host_idx on public.guests (host);

alter table public.guests enable row level security;

-- Guests are never readable or writable anonymously; the guest-rsvp
-- function reads them with the service role. Hosts may write only name and
-- phone, so the token is always the server-generated one.
revoke all on public.guests
from
  anon,
  authenticated;

grant
select
,
delete on public.guests to authenticated;

grant insert (id, host, name, phone),
update (name, phone) on public.guests to authenticated;
