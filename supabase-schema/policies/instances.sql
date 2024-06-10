-- Everyone can read public instances
create policy "Everyone can read public instances"
on "public"."instances"
as PERMISSIVE
for SELECT
to public
using (
    visibility = 'public'
);


-- Friends & members can read friends instances
create policy "Friends & members can read friends instances"
on "public"."instances"
as PERMISSIVE
for SELECT
to public
using (
    visibility = 'friends'
    AND (
        id IN (
            SELECT instance
            FROM instance_members
            WHERE member = auth.uid()
        )
        OR EXISTS (
            SELECT
            FROM friends
            WHERE friends.status = 'accepted'
            AND (
                auth.uid() in (requester, requestee)
                AND instances.created_by in (requester, requestee)
            )
        )
    )
);


-- Members can read private instances
create policy "Members can read private instances"
on "public"."instances"
as PERMISSIVE
for SELECT
to public
using (
    visibility = 'private'
    AND id IN (
        SELECT instance
        FROM instance_members
        WHERE member = auth.uid()
    )
);
