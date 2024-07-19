create policy "Creator & friends can read location points" on "public"."location_points" as PERMISSIVE for
SELECT
  to authenticated using (
    created_by = auth.uid ()
    OR EXISTS (
      SELECT
      FROM
        friends
      WHERE
        friends.status = 'accepted'
        AND (
          auth.uid () in (requester, requestee)
          AND location_points.created_by in (requester, requestee)
        )
    )
  );

create policy "Authenticated users can insert their own location points" on "public"."location_points" as PERMISSIVE for INSERT to authenticated
with
  check (
    (
      select
        auth.uid ()
    ) = created_by
    OR created_by IS NULL
  );

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