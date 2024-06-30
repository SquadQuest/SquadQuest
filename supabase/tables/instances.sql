create type public.instance_visibility as enum('private', 'friends', 'public');

create type public.instance_status as enum('draft', 'live', 'canceled');

create table
  public.instances (
    id uuid not null default gen_random_uuid (),
    created_at timestamp with time zone not null default now(),
    created_by uuid not null default uid (),
    updated_at timestamp with time zone null,
    status public.instance_status not null default 'live'::instance_status,
    start_time_min timestamp with time zone null,
    start_time_max timestamp with time zone null,
    topic uuid null,
    title character varying null,
    visibility public.instance_visibility null default 'private'::instance_visibility,
    location_description text not null,
    rally_point geography not null,
    rally_point_text text GENERATED ALWAYS AS (ST_AsText (rally_point)) STORED,
    constraint instances_pkey primary key (id),
    constraint instances_topic_fkey foreign key (topic) references topics (id),
    constraint instances_created_by_fkey foreign key (created_by) references profiles (id)
  );

create policy "Creators can always read their own events" on "public"."instances" as PERMISSIVE for
SELECT
  to authenticated using (created_by = auth.uid ());

create policy "Everyone can read public instances" on "public"."instances" as PERMISSIVE for
SELECT
  to authenticated using (
    visibility = 'public'
    AND status IN ('live', 'canceled')
  );

create policy "Creator & friends & members can read friends instances" on "public"."instances" as PERMISSIVE for
SELECT
  to authenticated using (
    visibility = 'friends'
    AND status IN ('live', 'canceled')
    AND (
      created_by = auth.uid ()
      OR id IN (
        SELECT
          instance
        FROM
          instance_members
        WHERE
          member = auth.uid ()
      )
      OR EXISTS (
        SELECT
        FROM
          friends
        WHERE
          friends.status = 'accepted'
          AND (
            auth.uid () in (requester, requestee)
            AND instances.created_by in (requester, requestee)
          )
      )
    )
  );

create policy "Creator & members can read private instances" on "public"."instances" as PERMISSIVE for
SELECT
  to authenticated using (
    visibility = 'private'
    AND status IN ('live', 'canceled')
    AND (
      created_by = auth.uid ()
      OR id IN (
        SELECT
          instance
        FROM
          instance_members
        WHERE
          member = auth.uid ()
      )
    )
  );

create policy "Authenticated users can insert instances" on "public"."instances" as PERMISSIVE for INSERT to authenticated
with
  check (
    auth.uid () = created_by
    OR created_by IS NULL
  );

create policy "Authenticated users can update their own instances" on "public"."instances" as PERMISSIVE for
UPDATE to authenticated using (created_by = auth.uid ())
with
  check (created_by = auth.uid ());

CREATE TRIGGER instance_rallypoint_change
AFTER
UPDATE OF rally_point ON instances FOR EACH ROW
execute function "supabase_functions"."http_request" (
  'http://functions:9000/update-rally-point',
  'POST',
  '{"Content-Type":"application/json"}',
  '{}',
  '1000'
);

CREATE TRIGGER instance_updated_timestamp BEFORE
UPDATE ON instances FOR EACH ROW
EXECUTE PROCEDURE set_updated_timestamp ();