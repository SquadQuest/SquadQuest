create policy "Users can read location points for events they have access to" on "public"."location_points" as PERMISSIVE for
SELECT
  to authenticated using (
    created_by = auth.uid ()
    OR (
      EXISTS (
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
      AND EXISTS (
        SELECT
          1
        FROM
          instances
        WHERE
          instances.id = location_points.event
          -- TODO: can we get rid of this and just rely on the instances view's existing policies?
          AND (
            -- Public events
            (
              instances.visibility = 'public'
              AND instances.status IN ('live', 'canceled')
            )
            OR
            -- Private events - must be member
            (
              instances.visibility = 'private'
              AND instances.status IN ('live', 'canceled')
              AND (
                instances.created_by = auth.uid ()
                OR EXISTS (
                  SELECT
                    1
                  FROM
                    instance_members
                  WHERE
                    instance_members.instance = instances.id
                    AND instance_members.member = auth.uid ()
                )
              )
            )
            OR
            -- Friends events - must be friend of creator OR member
            (
              instances.visibility = 'friends'
              AND instances.status IN ('live', 'canceled')
              AND (
                instances.created_by = auth.uid ()
                OR EXISTS (
                  SELECT
                    1
                  FROM
                    instance_members
                  WHERE
                    instance_members.instance = instances.id
                    AND instance_members.member = auth.uid ()
                )
                OR EXISTS (
                  SELECT
                    1
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
            )
          )
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