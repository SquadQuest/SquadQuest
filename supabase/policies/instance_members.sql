create policy "Authenticated users can read own, friends, an non-invite RSVPs" on "public"."instance_members" as PERMISSIVE for
SELECT
  to authenticated using (
    member = auth.uid ()
    OR created_by = auth.uid()
    OR status != 'invited'
    OR EXISTS (
      SELECT
      FROM
        friends
      WHERE
        friends.status = 'accepted'
        AND (
          auth.uid () in (requester, requestee)
          AND member in (requester, requestee)
        )
    )
  );