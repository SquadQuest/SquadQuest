-- Anyone can read all topics
create policy "Anyone can read all topics"
on "public"."topics"
as PERMISSIVE
for SELECT
to public
using (
    true
);


-- Authenticated users can insert topics
create policy "Authenticated users can insert topics"
on "public"."topics"
as PERMISSIVE
for INSERT
to authenticated
with check (
    true
);
