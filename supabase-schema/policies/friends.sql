-- Authenticated users can read all their friends of any status
create policy "Authenticated users can read all their friends of any status"
on "public"."friends"
as PERMISSIVE
for SELECT
to authenticated
using (
    auth.uid() in (requester, requestee)
);
