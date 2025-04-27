create type public.friend_status as enum('requested', 'declined', 'accepted');

create table
  public.friends (
    id uuid not null default gen_random_uuid (),
    created_at timestamp with time zone not null default now(),
    actioned_at timestamp with time zone null,
    requester uuid null,
    requestee uuid null,
    status public.friend_status null default 'requested'::friend_status,
    constraint friends_pkey primary key (id),
    constraint requester_requestee unique (requester, requestee),
    constraint friends_requester_fkey foreign key (requester) references profiles (id) on update cascade on delete cascade,
    constraint friends_requestee_fkey foreign key (requestee) references profiles (id) on update cascade on delete cascade
  );

alter table public.friends enable row level security;

create or replace view friends_mutuals as
with accepted_friends as (
  select requester, requestee
  from friends
  where status = 'accepted'
),
mutual_connections as (
  select
    f1.requester,
    f1.requestee,
    f2.requestee as mutual_friend
  from accepted_friends f1
  join accepted_friends f2 on
    (f2.requester = f1.requestee and f2.requestee != f1.requester)
  where exists (
    select 1 from accepted_friends f3
    where f3.requester = f1.requester and f3.requestee = f2.requestee
  )
  union
  select
    f1.requester,
    f1.requestee,
    f2.requester as mutual_friend
  from accepted_friends f1
  join accepted_friends f2 on
    (f2.requestee = f1.requestee and f2.requester != f1.requester)
  where exists (
    select 1 from accepted_friends f3
    where f3.requester = f1.requester and f3.requestee = f2.requester
  )
)
select
  requester,
  requestee,
  array_agg(distinct mutual_friend) as mutuals,
  array_length(array_agg(distinct mutual_friend), 1) as mutuals_count
from mutual_connections
group by requester, requestee;
