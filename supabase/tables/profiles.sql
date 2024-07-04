create table
  public.profiles (
    id uuid not null,
    first_name text not null,
    last_name text not null,
    phone text not null,
    fcm_token text null,
    photo text null,
    constraint profiles_pkey primary key (id),
    constraint profiles_id_fkey foreign key (id) references users (id)
  );

alter table public.profiles enable row level security;

create policy "Authenticated users can read their own and friends' profiles" on "public"."profiles" as PERMISSIVE for
SELECT
  to authenticated using (
    id = auth.uid ()
    OR EXISTS (
      SELECT
      FROM
        friends
      WHERE
        friends.status = 'accepted'
        AND (
          auth.uid () in (requester, requestee)
          AND profiles.id in (requester, requestee)
        )
    )
  );

create policy "Authenticated users can insert their own profile" on "public"."profiles" as PERMISSIVE for INSERT to authenticated
with
  check (id = auth.uid ());

create policy "Authenticated users can update their own profile" on "public"."profiles" as PERMISSIVE for
UPDATE to authenticated using (id = auth.uid ())
with
  check (id = auth.uid ());

CREATE VIEW
  profiles_anonymous
WITH
  (security_invoker = false) AS
SELECT
  id,
  first_name
FROM
  profiles;