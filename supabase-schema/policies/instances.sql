-- Everyone can read public instances
alter policy "Everyone can read public instances"
on "public"."instances"
to public
using (
    visibility = 'public'
);


-- Friends & members can read friends instances
alter policy "Friends & members can read friends instances"
on "public"."instances"
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
                or instances.created_by in (requester, requestee)
            )
        )
    )
);


-- Members can read private instances
alter policy "Members can read private instances"
on "public"."instances"
to public
using (
    visibility = 'private'
    AND id IN (
        SELECT instance
        FROM instance_members
        WHERE member = auth.uid()
    )
);
