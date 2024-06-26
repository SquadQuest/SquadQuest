create type public.friend_status as enum (
  'requested',
  'declined',
  'accepted'
);

create table public.friends (
  id uuid not null default gen_random_uuid (),
  created_at timestamp with time zone not null default now(),
  actioned_at timestamp with time zone null,
  requester uuid null,
  requestee uuid null,
  status public.friend_status null default 'requested' :: friend_status,
  constraint friends_pkey primary key (id),
  constraint requester_requestee unique (requester, requestee) constraint friends_requester_fkey foreign key (requester) references profiles (id),
  constraint friends_requestee_fkey foreign key (requestee) references profiles (id)
);

create policy "Authenticated users can read all their friends of any status" on "public"."friends" as PERMISSIVE for
SELECT
  to authenticated using (auth.uid() in (requester, requestee));