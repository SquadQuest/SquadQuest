create policy "Creator & friends can read location points"
on "public"."location_points"
as PERMISSIVE
for SELECT
to authenticated
using (
    created_by = auth.uid()
    OR EXISTS (
        SELECT
        FROM friends
        WHERE friends.status = 'accepted'
        AND (
            auth.uid() in (requester, requestee)
            AND location_points.created_by in (requester, requestee)
        )
    )
);


create policy "Authenticated users can insert their own location points"
on "public"."location_points"
as PERMISSIVE
for INSERT
to authenticated
with check (
    (select auth.uid()) = created_by
    OR created_by IS NULL
);
