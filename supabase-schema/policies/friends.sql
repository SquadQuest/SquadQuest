-- Authenticated users can read all xrefs
alter policy "Authenticated users can read all xrefs"
on "public"."friends"
to authenticated
using (
    true
);
