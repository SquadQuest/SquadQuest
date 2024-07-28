create table
  public.location_points (
    id uuid not null default gen_random_uuid (),
    created_at timestamp with time zone not null default now(),
    created_by uuid null default auth.uid (),
    event uuid not null,
    timestamp timestamp with time zone not null,
    location geography not null,
    location_text text GENERATED ALWAYS AS (ST_AsText (location)) STORED,
    constraint location_points_pkey primary key (id),
    constraint public_location_points_created_by_fkey foreign key (created_by) references profiles (id) on delete cascade,
    constraint public_location_points_event_fkey foreign key (event) references instances (id) on update cascade on delete cascade
  );

alter table public.location_points enable row level security;

-- trim old location data
SELECT
  cron.schedule (
    'trim location_points',
    '55 * * * *',
    'DELETE FROM location_points WHERE timestamp < NOW() - INTERVAL ''12 hour'';'
  );

CREATE FUNCTION get_users_with_location_points (for_event uuid) RETURNS uuid[] AS $$
  SELECT array_agg(DISTINCT created_by) FROM location_points WHERE event = for_event;
$$ LANGUAGE 'sql';

CREATE VIEW
  instance_points
WITH
  (security_invoker = true) AS
WITH
  latest_event_user_points AS (
    SELECT DISTINCT
      ON (event, created_by) event,
      created_by,
      timestamp,
      location
    FROM
      location_points
    ORDER BY
      event,
      created_by,
      timestamp DESC
  )
SELECT
  id,
  MAX(timestamp) AS latest,
  ST_AsText (rally_point) AS rally_point,
  COUNT(points.created_by) AS users,
  STRING_AGG(points.created_by::text, ';') AS user_ids,
  STRING_AGG(ST_AsText (location::geometry), ';') AS user_points,
  ST_AsText (ST_Centroid (ST_Union (location::geometry))) AS centroid,
  ST_AsText (
    ST_Centroid (
      ST_Union (
        ST_Union (location::geometry),
        rally_point::geometry
      )
    )
  ) AS centroid_with_rally_point,
  ST_AsText (ST_Envelope (ST_Union (location::geometry))) AS box,
  ST_AsText (
    ST_Envelope (
      ST_Union (
        ST_Union (location::geometry),
        rally_point::geometry
      )
    )
  ) AS box_with_rally_point
FROM
  instances
  LEFT JOIN latest_event_user_points AS points ON (points.event = instances.id)
GROUP BY
  instances.id;