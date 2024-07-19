create policy "Authenticated users can read all xrefs" on "public"."instance_members" as PERMISSIVE for
SELECT
  to authenticated using (true);