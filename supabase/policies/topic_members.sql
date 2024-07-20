create policy "Authenticated users can select their own topic memberships" on "public"."topic_members" as PERMISSIVE for
SELECT
    to authenticated using (member = auth.uid ());

create policy "Authenticated users can insert their own topic memberships" on "public"."topic_members" as PERMISSIVE for INSERT to authenticated
with
    check (member = auth.uid ());

create policy "Authenticated users can update their own topic memberships" on "public"."topic_members" as PERMISSIVE for
UPDATE to authenticated using (member = auth.uid ())
with
    check (member = auth.uid ());

create policy "Authenticated users can delete their own topic memberships" on "public"."topic_members" as PERMISSIVE for DELETE to authenticated using (member = auth.uid ());