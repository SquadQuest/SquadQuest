-- Authenticated users can read all xrefs
create policy "Authenticated users can read all xrefs"
on "public"."friends"
as PERMISSIVE
for SELECT
to authenticated
using (
    true
);
