-- A host manages guest rows only on events they created, and only for guests
-- that are theirs. Guests themselves never use these policies: they answer
-- through the guest-rsvp function, which runs as the service role.
create policy "Hosts can read guests on their own events" on "public"."instance_guests" as PERMISSIVE for
SELECT
  to authenticated using (
    instance IN (
      SELECT
        id
      FROM
        instances
      WHERE
        created_by = auth.uid ()
    )
  );

create policy "Hosts can add their guests to their own events" on "public"."instance_guests" as PERMISSIVE for INSERT to authenticated
with
  check (
    instance IN (
      SELECT
        id
      FROM
        instances
      WHERE
        created_by = auth.uid ()
    )
    AND guest IN (
      SELECT
        id
      FROM
        guests
      WHERE
        host = auth.uid ()
    )
  );

create policy "Hosts can update guests on their own events" on "public"."instance_guests" as PERMISSIVE for
UPDATE to authenticated using (
  instance IN (
    SELECT
      id
    FROM
      instances
    WHERE
      created_by = auth.uid ()
  )
)
with
  check (
    instance IN (
      SELECT
        id
      FROM
        instances
      WHERE
        created_by = auth.uid ()
    )
    AND guest IN (
      SELECT
        id
      FROM
        guests
      WHERE
        host = auth.uid ()
    )
  );

create policy "Hosts can remove guests from their own events" on "public"."instance_guests" as PERMISSIVE for DELETE to authenticated using (
  instance IN (
    SELECT
      id
    FROM
      instances
    WHERE
      created_by = auth.uid ()
  )
);
