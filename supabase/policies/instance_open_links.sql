-- A host manages open links only on events they created. Nobody reads a link
-- anonymously: the guest-rsvp function resolves it with the service role.
create policy "Hosts can read open links on their own events" on "public"."instance_open_links" as PERMISSIVE for
SELECT
  to authenticated using (created_by = auth.uid ());

create policy "Hosts can create open links on their own events" on "public"."instance_open_links" as PERMISSIVE for INSERT to authenticated
with
  check (
    created_by = auth.uid ()
    AND instance IN (
      SELECT
        id
      FROM
        instances
      WHERE
        created_by = auth.uid ()
    )
  );

create policy "Hosts can close open links on their own events" on "public"."instance_open_links" as PERMISSIVE for
UPDATE to authenticated using (created_by = auth.uid ())
with
  check (created_by = auth.uid ());

create policy "Hosts can delete open links on their own events" on "public"."instance_open_links" as PERMISSIVE for DELETE to authenticated using (created_by = auth.uid ());
