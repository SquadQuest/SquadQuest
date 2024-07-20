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