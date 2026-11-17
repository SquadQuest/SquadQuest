create policy "Hosts can read their own guests" on "public"."guests" as PERMISSIVE for
SELECT
  to authenticated using (host = auth.uid ());

create policy "Hosts can add their own guests" on "public"."guests" as PERMISSIVE for INSERT to authenticated
with
  check (host = auth.uid ());

create policy "Hosts can update their own guests" on "public"."guests" as PERMISSIVE for
UPDATE to authenticated using (host = auth.uid ())
with
  check (host = auth.uid ());

create policy "Hosts can delete their own guests" on "public"."guests" as PERMISSIVE for DELETE to authenticated using (host = auth.uid ());
