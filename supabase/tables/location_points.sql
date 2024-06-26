create table public.location_points (
  id uuid not null default gen_random_uuid (),
  created_at timestamp with time zone not null default now(),
  created_by uuid null default uid (),
  event uuid not null,
  timestamp timestamp with time zone not null,
  location geography not null,
  location_text text GENERATED ALWAYS AS (ST_AsText(location)) STORED,
  constraint location_points_pkey primary key (id),
  constraint public_location_points_created_by_fkey foreign key (created_by) references profiles (id) on delete cascade,
  constraint public_location_points_event_fkey foreign key (event) references instances (id) on update cascade on delete cascade
);

-- delete data older than 3 days every hour
SELECT
  cron.schedule(
    'trim location_points to 1 hour',
    '55 * * * *',
    'DELETE FROM location_points WHERE timestamp < now() - interval 1 hour'
  );

create policy "Creator & friends can read location points" on "public"."location_points" as PERMISSIVE for
SELECT
  to authenticated using (
    created_by = auth.uid()
    OR EXISTS (
      SELECT
      FROM
        friends
      WHERE
        friends.status = 'accepted'
        AND (
          auth.uid() in (requester, requestee)
          AND location_points.created_by in (requester, requestee)
        )
    )
  );

create policy "Authenticated users can insert their own location points" on "public"."location_points" as PERMISSIVE for
INSERT
  to authenticated with check (
    (
      select
        auth.uid()
    ) = created_by
    OR created_by IS NULL
  );