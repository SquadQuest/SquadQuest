-- Authenticated users can read all their friends of any status
create policy "Authenticated users can read all their friends of any status"
on "public"."friends"
as PERMISSIVE
for SELECT
to authenticated
using (
    auth.uid() in (requester, requestee)
);


create policy "Service Role can read all friends"
on "public"."friends"
as PERMISSIVE
for SELECT
to service_role
using (
    true
);

create policy "Service Role can insert friends"
on "public"."friends"
as PERMISSIVE
for INSERT
to public
with check (
    true
);


create policy "Service Role can update friends"
on "public"."friends"
as PERMISSIVE
for UPDATE
to public
with check (
    true
);
