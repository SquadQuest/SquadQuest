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

create or replace view friends_network as
with direct_friends as (
  SELECT requester AS friend
  FROM friends
  WHERE requestee = auth.uid() AND status IN ('accepted', 'requested')
  UNION
  SELECT requestee AS friend
  FROM friends
  WHERE requester = auth.uid() AND status = 'accepted'
),
friends_of_friends as (
  SELECT DISTINCT
    f.requestee as friend,
    array_agg(DISTINCT df.friend) FILTER (WHERE df.friend != auth.uid()) as mutuals
  FROM friends f
  JOIN direct_friends df ON f.requester = df.friend
  WHERE f.status = 'accepted'
    AND f.requestee != auth.uid()
    AND f.requestee NOT IN (SELECT friend FROM direct_friends)
  GROUP BY f.requestee
  UNION
  SELECT DISTINCT
    f.requester as friend,
    array_agg(DISTINCT df.friend) FILTER (WHERE df.friend != auth.uid()) as mutuals
  FROM friends f
  JOIN direct_friends df ON f.requestee = df.friend
  WHERE f.status = 'accepted'
    AND f.requester != auth.uid()
    AND f.requester NOT IN (SELECT friend FROM direct_friends)
  GROUP BY f.requester
),
mutual_friends as (
  SELECT
    df.friend,
    array_agg(DISTINCT
      CASE
        WHEN f2.requester = df.friend THEN f2.requestee
        ELSE f2.requester
      END
    ) FILTER (WHERE
      CASE
        WHEN f2.requester = df.friend THEN f2.requestee
        ELSE f2.requester
      END != auth.uid()
    ) as mutuals
  FROM direct_friends df
  JOIN friends f1 ON (f1.requester = df.friend OR f1.requestee = df.friend)
  JOIN friends f2 ON (
    (f2.requester = auth.uid() AND f2.requestee = CASE
      WHEN f1.requester = df.friend THEN f1.requestee
      ELSE f1.requester
    END)
    OR
    (f2.requestee = auth.uid() AND f2.requester = CASE
      WHEN f1.requester = df.friend THEN f1.requestee
      ELSE f1.requester
    END)
  )
  WHERE f1.status = 'accepted'
    AND f2.status = 'accepted'
  GROUP BY df.friend
),
direct_friends_with_profile as (
  SELECT
    df.friend as id,
    jsonb_build_object(
      'first_name', p.first_name,
      'last_name', p.last_name,
      'photo', p.photo,
      'trail_color', p.trail_color
    ) as profile,
    COALESCE(mf.mutuals, ARRAY[]::uuid[]) as mutuals
  FROM direct_friends df
  JOIN profiles p ON p.id = df.friend
  LEFT JOIN mutual_friends mf ON mf.friend = df.friend
),
fof_with_profile as (
  SELECT
    fof.friend as id,
    jsonb_build_object(
      'first_name', p.first_name
    ) as profile,
    fof.mutuals
  FROM friends_of_friends fof
  JOIN profiles p ON p.id = fof.friend
)
SELECT id, profile, mutuals FROM direct_friends_with_profile
UNION ALL
SELECT id, profile, mutuals FROM fof_with_profile;
